# ADR-0025: Budget (period-centric, category-targeted document)

## Status

Accepted

Date: 2026-06-28

**Supersedes:**

- The **aggregate choice** of [ADR-0006](./0006-budget-aggregate.md) (Budget as an event-sourced aggregate). Budget becomes a **Marten document**. The remainder of ADR-0006 — light per-period targets, no rollover, no enforcement, advisory-only, display-currency target — **stands** and is reaffirmed.

**Amends:**

- [ADR-0006](./0006-budget-aggregate.md) — the `CategoryKey` string (`domain:<svc>` / `tag:<text>`) becomes a **`CategoryId`** (per [ADR-0024](./0024-category-model.md)); actuals are sourced from `FlowRecorded` lines (per [ADR-0016](./0016-accounting-period-flow-ledger.md) / [ADR-0019](./0019-universal-line-items.md)), not `TransactionRecorded` + purchase-order settlement.

**Relates to:**

- [ADR-0024](./0024-category-model.md) — `CategoryId`, system + user categories.
- [ADR-0016](./0016-accounting-period-flow-ledger.md) / [ADR-0019](./0019-universal-line-items.md) — `FlowRecorded` lines as the actuals source.
- [ADR-0013](./0013-user-preferences-and-configurable-month.md) — period scoping; `DisplayCurrency`.
- [ADR-0008](./0008-multi-currency-and-fx.md) / [ADR-0015](./0015-fx-rate-sourcing-and-client-cache.md) — `CurrencyAmount`, FX.
- [ADR-0022](./0022-wishlist-items-packages-and-derived-status.md) — precedent for non-event-sourced user-authored state as a document.

## Context

ADR-0006 defined Budget as an event-sourced aggregate with a `CategoryKey` string, and sourced its actuals from `TransactionRecorded` plus purchase-order settlement. Two things changed underneath it:

1. **The transaction model moved.** ADR-0016 relocated everyday actuals to `FlowRecorded` on the per-period `AccountingPeriod` stream; ADR-0019 made those entries carry `list<Line>` with a per-line category. So budget actuals now group naturally by line, on the period stream — the old `TransactionRecorded` + PO settlement sourcing no longer applies.
2. **Categorization was re-modeled** (ADR-0024) from a dual-track `CategoryKey` string to a managed `CategoryId`. Budgets target a category entity, not a string.

Separately, Money has since established a clear precedent ([ADR-0013](./0013-user-preferences-and-configurable-month.md), [ADR-0022](./0022-wishlist-items-packages-and-derived-status.md)) that **user-authored current-state whose history is never consumed belongs outside the event store** as a plain Marten document. Budget targets are exactly that: a target is a preference ("I want to spend ≤ $X on Coffee this period"), and "when did I set my coffee budget?" is a question nobody asks. ADR-0006's "auditability" rationale for event-sourcing the target no longer holds against that precedent — while the *actuals* that feed a budget remain event-sourced (they are flows on `AccountingPeriod`).

Forces at play:

- The ledger (flows) stays event-sourced; the target is a preference. Mixing a preference into the event store buys unused auditability at real cost (a stream, events, a fold per budget).
- Budgets are read-mostly from the Wallet's perspective: the user sets targets, then sees actual-vs-target as the period progresses.
- Multi-currency (ADR-0008) means targets and actuals are in the display currency; line items in other currencies are converted.
- Budgets are advisory gauges that do **not** feed the savings-canvas total (the canvas uses total spend, not category sums) — so per-category tracking is independent and non-inflating.

## Decision

### Budget as a Marten document (supersedes ADR-0006's aggregate)

```
Budget {
  Id:            Guid,            // client-assigned (ADR-0003)
  OwnerId:       string,          // JWT sub (ADR-0004)
  Year, Month:   int,             // the configurable period (ADR-0013)
  CategoryId:    Guid,            // system or user category (ADR-0024)
  TargetAmount:  CurrencyAmount,  // display currency (ADR-0008)
  CreatedAt:     DateTimeOffset,
}
```

Keyed per **(owner, period, CategoryId)** — one document per budget. Read-all = `Query<Budget>().Where(b => b.OwnerId == owner && b.Year == y && b.Month == m)`. Writes are user-CRUD (set / clear / edit target). The aggregate, its stream, and its events (`BudgetTargetSet`, `BudgetTargetCleared`) from ADR-0006 are **removed**.

### Actuals aggregation — `BudgetActuals` projection

A `BudgetActuals` projection subscribes to `FlowRecorded` / `FlowReverted` (ADR-0016/0019) and emits one document per **(period, CategoryId)**:

```
BudgetActuals {
  OwnerId, (Year, Month), CategoryId,
  Spent: CurrencyAmount,   // display currency, event-time FX converted (see below)
}
```

- **Per-line grouping.** For each `FlowRecorded`, the projection inspects every `Line.CategoryId` and accumulates the line's amount into that category's `Spent`.
- **Signed sum.** Spending lines contribute `+`; refunds/credits in the same category contribute `−`. Net per category.
- **Event-time FX.** Each line amount is converted to the display currency at the FX rate **when the flow was recorded** (a stable "what it was worth" figure; no drift noise as FX moves). This is consistent with ADR-0015's "actuals use the transaction-date rate."
- **`FlowReverted`** reverses the affected lines.
- Mechanics (async incremental, consistent with ADR-0022's precedent) are formalized by the forthcoming projection-strategy ADR. This ADR fixes only the projection's *contract* (what it consumes and emits).

### Remaining = Target − Spent (read-time)

A budget's "remaining" is computed at read time from the target document + the `Spent` projection; it is **not stored.** The read endpoint returns `{ target, spent, remaining }` per category for the period.

### Rollover, enforcement, canvas

- **No rollover** (ADR-0006 stands). Each period's targets are independent; under/over-spend does not flow into the next period.
- **No enforcement** (ADR-0006 stands). Recording an over-budget transaction always succeeds; the Wallet surfaces over-spend visually. Money never rejects a flow based on budget state.
- **Does not feed the canvas.** Budgets are per-category gauges; the Home savings-canvas total uses total period spend, not category sums. So budgets neither inflate nor constrain the canvas, and double-counting a line across two category budgets (via two lines on one payment) is harmless.

### Per-period targets (no template aggregate)

Targets are **per-period**. The re-set-every-period click cost is handled client-side via a **"copy last period's targets"** bulk action (the Wallet composes N `set-target` calls). No recurring budget-template concept in v1.

### Archived categories (ADR-0024)

A budget targeting a soft-archived category still resolves for history (archived categories are still readable). The picker hides archived categories, discouraging new budgets against them.

### Endpoints

- `POST` / `PUT` / `DELETE` `/api/money/budgets/{id}` — set / edit / clear a target (user categories and system categories both targetable).
- `GET /api/money/budgets?year=&month=` — list targets for a period.
- `GET /api/money/budgets/{id}/status` (or a period rollup) → `{ target, spent, remaining }`.

## Consequences

Positive:

- Budget is simple current-state CRUD (no stream, no events, no fold) — matches how it is actually used, and consistent with the ADR-0013/0022 precedent for user-authored state.
- The ledger stays event-sourced (flows on `AccountingPeriod`); only the target moves out of the event store. Clean separation of "preference" from "ledger."
- Per-line categorization (ADR-0019/0024) lets one payment contribute to several budgets naturally.
- Reads are cheap (target doc + spent projection, zipped at read time).

Negative:

- A non-trivial projection (consumes `FlowRecorded` lines, per-line grouping, event-time FX). Bounded per category and low-volume at solo scale, but it is real write-side infrastructure.
- Supersedes ADR-0006's aggregate choice and amends its sourcing — requires cross-reference updates. Both are pre-implementation, so the refactor cost is zero.

Neutral:

- Money now has four non-event-sourced document stores (UserPreferences, FX rates, Wishlist items/packages, Budget) alongside its event streams and projections.

## Alternatives Considered

1. **Keep Budget as an event-sourced aggregate (ADR-0006 as-is).** Rejected: targets are user-authored current-state whose history is never consumed — directly on-point with the ADR-0013/0022 precedent. Event-sourcing buys unused auditability at real cost. The ledger (flows) remains event-sourced; the target does not need to be.
2. **Store `remaining` on the document.** Rejected: `remaining = target − spent`, and `spent` is a live projection over flows. Storing `remaining` would duplicate derivable state and go stale. Compute it at read time.
3. **Read-time FX conversion for actuals.** Rejected for actuals: live-rate conversion makes historical `spent` drift as FX moves, turning a stable figure into noise. Event-time FX (the rate when the flow was recorded) is stable and matches ADR-0015's actuals policy. Revaluation-at-close can be revisited later.
4. **Recurring budget templates (a template that auto-applies each period).** Rejected for v1: per-period targets + a client-side "copy last period" bulk action cover the re-set cost without a new aggregate. Templates can be added non-breakingly if the click cost proves real.
5. **Validate allocations/spending against budget (enforcement).** Rejected (ADR-0006 stands): budgets are advisory; spend-blocking is explicitly out of scope (`apps/wallet/PLAN.md` §11).

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.

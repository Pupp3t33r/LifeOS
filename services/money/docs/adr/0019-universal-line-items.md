# ADR-0019: Universal line-items for spending entries and estimates

## Status

Accepted

Date: 2026-06-27

**Amends:**

- [ADR-0016](./0016-accounting-period-flow-ledger.md) — `FlowRecorded` replaces its single `CurrencyAmount` + `tags` fields with `Lines: list<Line>` (1..N). Direction, date, description, links unchanged.
- [ADR-0017](./0017-recurring-payment-rules-and-schedules.md) — the Live rule's estimate and the Materialized `ScheduleLine.ExpectedAmount` each become `list<Line>`.

**Relates to:** [ADR-0018](./0018-planned-purchases-on-accounting-period.md) (`PlannedPurchaseAdded`/`Edited` carry `list<Line>`), [ADR-0008](./0008-multi-currency-and-fx.md) (`CurrencyAmount`), [ADR-0006](./0006-budget-aggregate.md) (per-line categorization), [ADR-0022](./0022-wishlist-items-packages-and-derived-status.md) (`Line.WishlistItemId`).

## Context

ADR-0016 and ADR-0017 carried a **single monetary amount** per flow entry and per recurring estimate/occurrence. Real spending is finer-grained:

- A grocery run is one payment but may be logged as one item ("groceries"), grouped ("sweets", "soda", "fruits"), or itemized ("bag of chips", "cookies", …) — each with its own tag. Receipt scanning (future, via the Document Processing service) produces many lines automatically.
- A preorder bundle is one payment with a breakdown (base + addons + shipping); the first payment may include shipping while later installments do not.
- Different lines hit different budgets (a game line → `domain:board-games`; a shipping line → `tag:shipping`).

Forcing one amount per entry/occurrence means the planner cannot represent breakdowns, budgets cannot split a single payment across categories, and the only way to itemize is to create many separate entries — losing the "one payment" relationship and any shared delivery line.

Forces at play:

- ADR-0008 mandates `CurrencyAmount` (never bare `decimal`). Lines share the entry's currency (a purchase happens in one currency); each line's amount is still a `CurrencyAmount` for consistency.
- ADR-0006 categorizes budgets by `domain:<serviceType>` or `tag:<text>`. Per-line categories let one entry contribute to several budgets.
- The breakdown is needed on **both sides**: the planned estimate (`PlannedPurchaseAdded`, recurring schedule) and the actual (`FlowRecorded`). At confirm, the actual lines may differ from the estimate (used copy, fewer addons) — the ADR-0017 "actual adjustable at confirm" pattern, generalized to lines.
- ADR-0016's `FlowRecorded` carried a separate `tags` field; with per-line categories, tags move onto the line and the entry-level `tags` field is removed.

## Decision

### The `Line` value object

```
Line {
  Description?:    string,                         // optional: "Bag of chips", "Base game", "Shipping"
  Amount:          CurrencyAmount,                  // ADR-0008; lines share the entry's currency
  Category:        ExternalReference? | Tag?,        // dual-track (ADR-0006): domain link OR free-text tag; nullable
  WishlistItemId?: Guid,                            // optional back-ref to a wishlist item (ADR-0022)
}
```

- `Category` is a discriminated union: an `ExternalReference(serviceType, externalId)` (domain categorization) **or** a free-text `Tag` (tag categorization). Nullable for a generic/uncategorized line. The storage mechanics of `Tag` remain subject to the deferred tag-storage decision (ADR README); this ADR fixes only the on-the-wire shape.
- `WishlistItemId` is optional; present when the line realizes (part of) a wishlist item, so the derived-status projection (ADR-0022) can update that item's state. A recurring preorder's schedule-line items carry this too.
- **Delivery is an ordinary line**: `Tag = "shipping"`, no `ExternalReference`, no `WishlistItemId`. Its proportional allocation across item lines (for asset acquired cost) is the Phase-3 computation captured in [ADR-0018](./0018-planned-purchases-on-accounting-period.md).

### Every spending entry/estimate carries `list<Line>`

- **`FlowRecorded`** (ADR-0016): `CurrencyAmount` + `tags` are replaced by `Lines: list<Line>` (1..N). Entry total = Σ line amounts.
- **`PlannedPurchaseAdded` / `PlannedPurchaseEdited`** (ADR-0018): carry `Lines: list<Line>` (1..N). Same `Line` shape.
- **Recurring estimates** (ADR-0017):
  - **Live** rule's estimate becomes `list<Line>` — one breakdown applied **uniformly to every computed occurrence**, editable via rule edit (forward-only; past confirmed actuals are immutable).
  - **Materialized** `ScheduleLine.ExpectedAmount` becomes `list<Line>` — each schedule line carries its own breakdown, **varying per payment** (e.g., shipping in line 1 only).
  - The confirmed `FlowRecorded` for a recurring occurrence is multi-line and may differ from the estimate.

### Single currency per entry

All `Line`s within one `FlowRecorded`, `PlannedPurchaseAdded`, or schedule line share one currency (the entry's currency). Cross-currency within a single entry is not supported (a purchase happens in one currency). The period still mixes currencies **across** entries (ADR-0016).

### Idempotency and payload comparison (ADR-0003)

ADR-0003 dedup compares payloads by `EntryId`. With `list<Line>` payloads, comparison is **structural** (same lines, same order): 200 on identical replay, 409 on conflicting payload. Lines are ordered within an entry (stable sequence).

### Budgets consume per-line categories (ADR-0006)

Budget categorization is applied **per line**, not per entry. A single multi-line `FlowRecorded` can contribute to several budgets in one payment. The budget projection sums line amounts grouped by `Category`.

## Consequences

Positive:

- Breakdowns are first-class: itemized groceries, preorder bundles with shipping, receipt-scan output — all one entry with N lines.
- Budgets gain per-line granularity from a single payment (no need for separate entries to hit multiple categories).
- The "one payment" relationship is preserved (lines share an entry) while remaining individually categorizable.
- Forward-compatible with receipt scanning (a receipt *is* a list of lines).
- Recurring estimates gain the same breakdown power (all-in preorder with shipping in payment 1; grouped "living expenses" as one Live recurring).

Negative:

- Every monetary total is a Σ over lines; the total is no longer a single stored field. Mitigated: projections may denormalize the entry total alongside the lines.
- Multi-line payloads make ADR-0003 payload comparison slightly heavier (ordered list equality vs scalar). Acceptable.
- Amends two frozen ADRs (0016, 0017). Both are pre-implementation (the young Transactions feature), so the refactor cost is low.

Neutral:

- A one-line entry is the common case (degenerate N=1); the model imposes no overhead on simple logging.

## Alternatives Considered

1. **Single amount per entry; itemize via multiple entries.** Rejected: loses the "one payment" relationship (a grocery run becomes N unrelated entries), cannot share a delivery line across items, and budget-splitting a single real payment is artificial.
2. **Line-items only on `FlowRecorded` (actuals), not on estimates.** Rejected: the preorder-shipping-in-payment-1 structure is a *planning* concern (the user wants to plan the breakdown ahead), so estimates need lines too. Confirm-time-only breakdown would lose planned structure.
3. **Bare `decimal` per line (no `CurrencyAmount`).** Rejected: violates ADR-0008. Lines share the entry's currency, but each amount is still a `CurrencyAmount`.
4. **Per-line currency (cross-currency entries).** Rejected: a purchase happens in one currency. Cross-currency concerns live across entries (the period mixes currencies), not within one entry.

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.

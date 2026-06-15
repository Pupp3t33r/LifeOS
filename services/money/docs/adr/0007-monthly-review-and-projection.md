# ADR-0007: MonthlyReview aggregate, Month projection, and month-close flow

## Status

Accepted

Date: 2026-06-15

## Context

The Wallet app's Home screen is a **savings canvas** built around three numbers per month:

- **Target savings** — user-set goal ("I want to save \$1,000 this month").
- **Projected savings** — computed: `projected income − projected spending − planned purchases` (where planned purchases = Wishlist items promoted into PurchaseOrders in Planned status for that month).
- **Actual savings (override)** — user-entered real number that accounts for untracked spending. This is the *honesty valve* that lets the planner tolerate gaps in transaction logging without forcing the user to itemize every coffee.

Nothing in ADR-0005's aggregate taxonomy holds this state. The actual-override in particular has no home — it is neither a transaction (it's a single number per month, not a ledger entry) nor a budget (it's a top-level savings figure, not per-category).

Forces at play:

- The Wallet must render the canvas from a single composed read-model; piecing it together client-side from many endpoints would duplicate projection logic and create a slow, chatty UI.
- "Month close" is a real workflow: at month-end the user reviews, locks the month, and the surplus/deficit converts to the savings account's currency at the close-day FX rate (see ADR-0008, ADR-0009). This operation must be atomic and auditable.
- The user wants each month to be **independent** — past months are not editable after close (with one exception: pre-existing asset import per ADR-0010 bypasses the month flow entirely).
- Multi-currency means the canvas must aggregate into a single display currency for readability, while preserving the original currency on each line item.
- The projected-savings computation depends on data from four other aggregates (Recurring, Installments, Wishlist→PurchaseOrder, Budgets) plus actuals from TransactionRecord. It is a **composed read-model**, not state any single aggregate owns.

## Decision

### MonthlyReview aggregate

Add a **`MonthlyReview` aggregate** to Money:

| Field | Type | Notes |
|---|---|---|
| `OwnerId` | string | From JWT `sub` (ADR-0004) |
| `Year`, `Month` | int | The period |
| `TargetSavings` | Money | User-set goal, in display currency |
| `ActualSavingsOverride` | Money? | Nullable. When present, this is the truth; otherwise the UI shows projected. |
| `Notes` | string? | Optional free text ("ate out too much") |
| `Status` | enum | `Open` or `Closed` |
| `ClosedAt` | DateTimeOffset? | Set when transitioned to Closed |
| `ClosingFxRates` | Dictionary<string, decimal>? | Snapshot of FX rates used at close, keyed by currency code |

Stream key: `monthly-review/{OwnerId}/{Year}/{Month}`. One stream per user per month.

### Events

- `MonthOpened` — initialized with `TargetSavings`. Emitted lazily (first time the user interacts with a month).
- `TargetSavingsSet` — change the target while Open.
- `ActualSavingsOverridden` — set or update the override while Open.
- `MonthClosed` — locks the month, captures `ClosedAt` and `ClosingFxRates`. Computes and persists a snapshot of the projected-vs-actual numbers at close time.

Once closed, no further events on this stream are accepted (the handler rejects writes with 409).

### Month projection read-model

A new **`MonthProjection`** document, computed (not authoritative state) by consuming events from:

- `RecurringPayment` (ADR-0005) — projected income/outgo for the month.
- `InstallmentPlan` (ADR-0005) — scheduled payments falling in the month.
- `PurchaseOrder` (ADR-0005) — Planned-status POs whose target month matches.
- `Budget` (ADR-0006) — category targets, joined against actuals.
- `TransactionRecord` (ADR-0005) — actuals logged in the month.
- `MonthlyReview` — target, override, status, close snapshot.

The projection outputs, in the user's display currency:

```
{
  targetSavings, projectedIncome, projectedSpending, plannedPurchases,
  projectedSavings, actualSavingsOverride (nullable),
  closed (bool), closedAt, lineItems: [{ source, originalAmount, originalCurrency, convertedAmount }]
}
```

Each line item retains its original currency for inline display ("€80 (~\$86)") per `apps/wallet/PLAN.md`. The projection is **not** authoritative — it is rebuilt from events; never edited directly.

### Month-close flow

When the user closes a month:

1. The handler appends `MonthClosed` to the `monthly-review/{Owner}/{Year}/{Month}` stream.
2. The closing handler reads `MonthProjection` to get projected savings.
3. The **final savings number** = `ActualSavingsOverride ?? projectedSavings`.
4. If `final != 0`, a transfer transaction is appended to the relevant savings account's stream (ADR-0009) — surplus deposits, deficit withdraws — converted at the close-day FX rates captured in `ClosingFxRates`.
5. The Month projection is updated to reflect the closed state.

### Independence and lock semantics

- Each `(Year, Month)` is its own aggregate. April's actual does not affect May's target.
- After `MonthClosed`, the month is locked. Past-month transactions are not editable. The exception is pre-existing Asset import (ADR-0010), which bypasses MonthlyReview entirely — it creates Assets directly without touching any month's flow.
- The user may close a month late (e.g., close April in mid-May). The `ClosedAt` timestamp records when; the FX snapshot uses the close-day rates, not the calendar-end rates.

## Consequences

Positive:

- The savings canvas has a single authoritative read-model (`MonthProjection`) — the Wallet's Home screen is one query.
- The actual-override honesty valve is a first-class concept, not a hack.
- Month close is auditable (events, FX snapshot, timestamp) and atomic (single transaction).
- Independence makes reasoning simple — past months don't shift under you.
- Pre-existing asset import is cleanly excluded from month flow.

Negative:

- `MonthProjection` consumes events from six aggregate families. The projection is non-trivial to build and rebuild.
- Lock semantics mean the user cannot fix mistakes in closed months without an admin/unclose operation (not in v1). Mitigation: keep the close action deliberate (confirmation prompt in UI).
- Late close uses close-day FX rates, which can differ materially from calendar-end rates if the user closes weeks late. This is intentional (the conversion happens when the user actually does the review), but worth flagging.

Neutral:

- `MonthProjection` could be inline (updated on each event) or async (rebuilt on read). Strategy is the subject of the "Projection strategy" deferred decision in the ADR README; this ADR does not pick one.

## Alternatives Considered

1. **No MonthlyReview aggregate; project everything from raw events.** The override and target would live in a side table or app config. Rejected: target and override are user-authored state with lifecycle; they deserve event sourcing for auditability. A projection-only model loses the "who set target to \$X when" history.
2. **No month-close flow; months are always editable.** Rejected by user: close-with-lock is the intended discipline, with pre-existing-asset-import as the explicit bypass.
3. **Auto-close at calendar month-end via cron.** Rejected: close is a deliberate user review action, not an automated one. FX snapshot must capture close-time rates; auto-close at midnight UTC would use stale rates and skip the review.
4. **Multi-month rollup as part of MonthlyReview.** Rejected: each month is independent (per user). Long-term analytics is Phase 5 work; it reads many MonthlyReview streams, does not belong on the per-month aggregate.

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.

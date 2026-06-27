# ADR-0021: Close flow — multi-account allocation and item dispositions

## Status

Accepted

Date: 2026-06-27

**Amends:**

- [ADR-0007](./0007-monthly-review-and-projection.md) — month-close flow: the surplus/deficit is **allocated across multiple savings accounts**; unpaid-item dispositions are added to the close transaction.
- [ADR-0009](./0009-savings-accounts-and-month-close.md) — close deposits/withdrawals go to **multiple** savings accounts (one or more), not a single designated account.

**Relates to:** [ADR-0016](./0016-accounting-period-flow-ledger.md) (`MonthClosed`, lock), [ADR-0018](./0018-planned-purchases-on-accounting-period.md) (planned-purchase carry via `Origin`), [ADR-0017](./0017-recurring-payment-rules-and-schedules.md) / [ADR-0020](./0020-recurring-live-carry-make-up-defer.md) (recurring dispositions), [ADR-0008](./0008-multi-currency-and-fx.md) (`ClosingFxRates`), [ADR-0023](./0023-active-month-model.md) (next-period opening on carry).

## Context

ADR-0007/0009's close flow computed the final savings number (`ActualSavingsOverride ?? projectedSavings`) and deposited/withdrew the **entire** surplus/deficit to **one** designated savings account, converted at close-day FX. "Single account" then meant a single account *type* (savings); ADR-0009 subsequently established that a user may hold **multiple savings accounts in different currencies**. The user now needs to **allocate** a surplus across several accounts (park some in the EUR account, some in the USD account) — the primary driver is multi-currency, with per-account interest a future possibility.

Separately, the period-centric model ([ADR-0018](./0018-planned-purchases-on-accounting-period.md)) and recurring occurrences ([ADR-0017](./0017-recurring-payment-rules-and-schedules.md)) mean a closing period typically holds **unpaid items** — unconfirmed planned purchases and unconfirmed recurring occurrences. The close flow must give each a disposition (cancel, defer, skip, re-date, carry-make-up); leaving them unresolved would freeze ambiguity into the locked period, which rejects events after close.

Forces at play:

- ADR-0007 captures `ClosingFxRates` at close; multi-account allocation converts each allocation to its target account's currency at those rates.
- The close is a deliberate user action (ADR-0007 rejected auto-close). The user reviews, allocates, disposes unpaid items, and locks — in one atomic operation.
- Lock is absolute after `MonthClosed` (ADR-0007/0016). The close transaction must complete fully or not at all.
- Per [ADR-0021's sibling decisions](./), dispositions are **uniform** — no obligation flag — so every choice is available for every item.

## Decision

### Split allocation across accounts

At close, the user **allocates their actual savings across one or more savings accounts**. Each allocation produces a **savings movement** on the target account's stream:

- **Surplus** → a deposit (per account), converted to that account's currency at `ClosingFxRates`.
- **Deficit** → a withdrawal (per account), same conversion. The user chooses which account(s) absorb the deficit — the mirror of surplus allocation.

The single designated account of ADR-0009 is the degenerate case (one allocation).

### Allocation entry (user-truth, not validated)

- The user enters each allocation **in the target account's currency** ("€200 to the EUR account"); the system shows the display-currency equivalent for readability.
- **Allocations are NOT validated against the projected surplus/deficit.** This is intentional and is the point of the close ceremony: the user's real savings may diverge from the computed projection (un-logged coffees, cash spending, etc.), and the close is where reality is recorded. The user allocates what they actually saved; the system records it without second-guessing. (See the deferred override-vs-allocations question below.)
- Each allocation movement carries its own idempotency key (ADR-0003).

### Dispositions at close

Every unpaid item in the closing period receives a disposition, chosen by the user, appended in the close transaction:

| Item type | Disposition choices | Event(s) |
|---|---|---|
| Planned purchase (one-off) | **cancel** (terminal) / **defer** (carry to next month) | `PlannedPurchaseCancelled` / next-period `PlannedPurchaseAdded` (with `Origin`) |
| Recurring — Live occurrence | **skip** / **carry-make-up** (ADR-0020) | `OccurrenceSkipped` / skip + next-period `PlannedPurchaseAdded` |
| Recurring — Materialized line | **re-date** (forward) / **skip** | `ScheduleLineEdited` (recurring stream) / `OccurrenceSkipped` |
| Ad-hoc paid (`FlowRecorded`) | n/a — it is an actual | — |

(Series-wide **cancel** of a recurring payment is a standalone action on the recurring aggregate per ADR-0017, not a per-item close disposition.)

No obligation flag: every choice is available for every item. Bulk actions (e.g. "skip all unconfirmed recurring") are a Wallet UI convenience, not a Money concern.

### Carry writes to the next period

Deferring a planned purchase or carry-make-up of a Live occurrence appends a `PlannedPurchaseAdded` to the **next period's** stream within the same close transaction. Whether the next period must already be open or is opened by the close itself is governed by the active-month model ([ADR-0023](./0023-active-month-model.md)). The closing period's locked snapshot shows the carried item via the next-period `Origin` join (no marker event on the closing period).

### Atomicity

The entire close — `MonthClosed` (period stream) + N allocation movements (account streams) + disposition events (period / recurring / next-period streams) — is **intended to append in one Marten transaction** (intra-Money atomicity, ADR-0005). If any part fails, the close fails: no partial close, no partial allocation, no partial lock. The exact atomicity boundary is **tentative, to be confirmed during implementation** (the close spans several streams; implementation will validate that a single transaction is the right fit).

### Reversibility

Close is **permanent in v1** (consistent with ADR-0007): no unclose, no undo window. The savings movements are real ledger entries already appended; reversing would require compensating events and is out of scope. Mitigation: a strong confirmation prompt (the Wallet shows the full allocation + dispositions + resulting balances before confirming). An unclose/admin path is a future enhancement, not v1.

## Consequences

Positive:

- Multi-currency users allocate surplus/deficit across accounts at close — the real action they need.
- Every unpaid item gets an explicit disposition; no ambiguity is frozen into the locked period.
- The close is atomic — allocation, dispositions, and lock commit together or not at all.
- Deficit is the clean mirror of surplus (user-chosen withdrawal accounts).

Negative:

- The close transaction spans multiple streams (period + N accounts + recurring + next-period) — larger than ADR-0007's single-movement close, but still one Marten transaction at solo volume.
- Amends two frozen ADRs (0007, 0009). Both are pre-implementation, so the refactor cost is low.
- Permanent close with no undo: a mistaken close requires compensating manual entries. Mitigated by the confirmation prompt.

Neutral:

- The single-account close of ADR-0009 is the degenerate case (one allocation).

## Deferred sub-decisions (captured, non-blocking)

- **`ActualSavingsOverride` vs allocations** (deferred — touches ADR-0007's core): with allocations as user-truth, the override's role needs settling. Open threads to resolve together when ADR-0007 is revisited:
  - (a) does the **sum of allocations** (display currency) become the actual savings, folding the override (amends `final = override ?? projected`)?
  - (b) the user wants a **per-month +/− variance display** (projected vs actual) — where does that live?
  - (c) **dipping into savings for a purchase** — can a specific expense draw directly from a savings account mid-month (a savings movement tied to a purchase), or does savings only ever move via the close deficit? Under the current model (ADR-0016), flow actuals don't touch accounts mid-month; this asks whether a purchase can be an explicit mid-month savings withdrawal.
- **Edit-after-close**: v1 forbids any change to a closed period (consistent with ADR-0007). A future "edit after close" capability — if ever added — would be a system adjacent to the backfill mechanism, **not** an undo window. Out of scope for v1.0; a discussion for another time.
- **Close-dialog shape** (single screen vs multi-step wizard): a Wallet UX concern, out of scope for Money.
- **Per-item explicit disposition vs auto-default-with-override**: whether the close requires the user to decide each unpaid item, or applies defaults (skip recurring, carry planned purchases) that the user overrides — a Wallet UX concern.

## Alternatives Considered

1. **Single account (ADR-0007/0009 as-is).** Rejected: the multi-account reality means users want to allocate across currencies; forcing one account is artificially limiting.
2. **Split allocation auto-decided (no user input).** Rejected: which account gets what is a deliberate savings-strategy decision; the system should not choose.
3. **Close without dispositions (leave unpaid items in the locked period).** Rejected: freezes ambiguity — unpaid items in a locked period have no resolution path, since the period rejects events after close. Dispositions must happen at or before close.
4. **Undo window (e.g. 5 min) for close.** Rejected for v1: the savings movements are real ledger entries; an undo window complicates idempotency and audit. Strong confirmation is the mitigation; unclose is a future enhancement.
5. **Auto-dispose unresolved items as the only path.** Rejected: the user should decide arrears vs abandon per item (rent carry-make-up vs subscription skip). Auto-defaults may be offered as a UI convenience on top, but not as the sole mechanism.

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.

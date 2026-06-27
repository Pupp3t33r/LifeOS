# ADR-0023: Active-month model and period write permissions

## Status

Accepted

Date: 2026-06-27

**Refines:** the active-month / period-write model implied by [ADR-0007](./0007-monthly-review-and-projection.md) (lazy `MonthOpened`, independent periods) and the "exactly one open period" framing in [Wallet PLAN](../../../../apps/wallet/PLAN.md) §12. This ADR clarifies the period write model: **future periods accept planning operations only**; **"one open period" is a UI/active-period default, not a write invariant.**

**Relates to:** [ADR-0016](./0016-accounting-period-flow-ledger.md) (period streams; actuals route by date), [ADR-0013](./0013-user-preferences-and-configurable-month.md) (period mapping → current period by date), [ADR-0021](./0021-close-flow-multi-account-allocation-and-dispositions.md) (resolves its "does close open the next period?" open question), [ADR-0017](./0017-recurring-payment-rules-and-schedules.md) (occurrences by date).

## Context

The Wallet PLAN framed the active-month model as "exactly one open (editable) period; past/future view-only; advancing requires explicit month-close." But the planner also needs to **plan future periods** — promote a wishlist item to next month while the current month is still active ("I see headroom next month; I'll schedule the board game then"). A hard "one writable period" invariant blocks that, forcing an awkward close-current-then-plan-next dance.

Re-examining the constraint, the forces behind "one open period" were (a) avoid "which month am I in?" confusion, and (b) nudge the user to close past-due periods (the red button). **Neither requires a hard write block on future periods.** Meanwhile ADR-0016 already routes `FlowRecorded` to the period of its actual date, and ADR-0007 emits `MonthOpened` lazily — both treat periods as independent. The simplest model consistent with all of it: **a period is writable until it is closed; multiple periods may be open; "active" is a UI designation of the current month.**

Forces at play:

- Future planning is a real need (the board-game scenario); blocking it adds ceremony without value.
- Actuals auto-route by date (ADR-0016), so recording a transaction does not depend on which period is "active."
- Close locks a period (ADR-0007/0016); that is the real immutability boundary.
- The "active period" concept is about UI focus (Home shows the current month) and the overdue-close nudge. Write permissions do differ by recency (future periods are planning-only — see Decision), but that follows from what makes sense, not from a hard "one open period" rule.

## Decision

### Write permissions by period recency (not a stored status)

A period's permitted writes are derived from its date relative to today and its closed flag — **not** a stored status field:

| Period (relative to today) | Closed? | Permitted writes |
|---|---|---|
| **Past-due open** (ended before today, not yet closed) | no | full (planning, actuals by date incl. late-logged, lifecycle, close) |
| **Active** (contains today) | no | full (planning, actuals by date, lifecycle, close) |
| **Future** (starts after today) | no | **planning operations only** |
| any | yes (`MonthClosed`) | none — locked (ADR-0007/0016) |

**Future periods accept planning operations only** — adding, editing, and cancelling planned purchases (`PlannedPurchaseAdded` / `Edited` / `Cancelled`). Specifically excluded from future periods:

- ✗ Recording actuals (`FlowRecorded`) — actuals route to the period of their **actual date** (ADR-0016), which is by definition today-or-past; a future-dated actual is invalid.
- ✗ Closing (`MonthClosed`) — a future period is not yet reviewable.
- ✗ Review lifecycle (`TargetSavingsSet`, `ActualSavingsOverridden`) — these belong to the active/review period. (Whether a future period's *target* may be set ahead is a minor detail; default: set when the period becomes active.)

Paying for an item scheduled in a future period from the current month (early payment) is **not** a plain future-period write — it needs special handling and is deferred (below).

### The active period is a UI designation

The **active period** is the period containing the current date (per ADR-0013's period mapping). The Wallet's Home highlights it. The user may view and plan any open period (future included), but the active period is the focus and the only one that can record actuals or be closed. "One open period" is a **UI default + close nudge**, not a write block; multiple periods may be open simultaneously (e.g., the active period plus one or more future periods being planned).

### Close locks; no "open next" ceremony

Closing a period appends `MonthClosed` and locks it (ADR-0007/0016). It does **not** "open" the next period — the next period is already plannable (future periods accept planning operations). **This resolves the open question in [ADR-0021](./0021-close-flow-multi-account-allocation-and-dispositions.md)** ("must the next period already be open, or does close open it?"): neither; periods accept planning on demand. Carry-at-close writes a `PlannedPurchaseAdded` to the next period's stream directly — a planning operation, permitted even though the next period is future.

### Past-due close nudge

When the current date has advanced past the active period's nominal close (e.g., it is June but March is still open), the Wallet shows a prominent "close this period" prompt (the red button). This is the operational expression of "one open period at a time" — a discipline nudge enforced by UX, not by the write side.

## Deferred sub-decisions (captured, non-blocking)

- **Skip-periods (catch-up UX)**: if the user is months behind (March open, now June, with April/May never touched), the catch-up flow — closing March and "skipping" untouched intervening periods to land on June — is a Wallet UX concern. Periods that were never created (no stream) need no closing; only periods with content need explicit close. Deferred.
- **Early payment of a future-period installment**: paying a Materialized recurring line scheduled for a future period from the current month (e.g., pay July's installment in June to close debt early). ADR-0016 routes the `FlowRecorded` to the period of its actual date (June), back-referencing the future line. This raises a **cross-period occurrence-tracking and idempotency** question: the future line's "paid" status and the "already confirmed?" idempotency check (ADR-0017, currently within-one-period) must work across periods. This likely amends ADR-0016/0017 and is deferred until early-payment is implemented.

## Consequences

Positive:

- Future planning works without ceremony (matches the board-game scenario).
- Consistent with ADR-0016 (actuals by date) and ADR-0007 (lazy `MonthOpened`, independent periods).
- "One open period" becomes an honest UI default + nudge rather than a forced write block.
- Closes the ADR-0021 next-period-opening question cleanly (no open ceremony).

Negative:

- Multiple open periods could mildly confuse "which month am I editing?" — mitigated by the active-period UI focus and the past-due close nudge.
- Early payment (deferred) will need cross-period occurrence tracking when implemented.

Neutral:

- Close no longer "opens" anything; the open/close asymmetry implied by ADR-0007 is simplified.

## Alternatives Considered

1. **Hard "one writable period" invariant (block future writes).** Rejected: blocks needed future planning; forces close-then-plan ceremony; inconsistent with the independence ADR-0007/0016 already established.
2. **Three stored period states (`Projected` / `Open` / `Closed`).** Rejected as unnecessary: the recency-based write distinction (future = planning-only, active/past-due = full, closed = locked) is **derived from date + closed flag**, not a stored status. No `Projected` field is needed; the "active" designation lives UI-side.
3. **Auto-close past-due periods.** Rejected (ADR-0007 Alt 3): close is a deliberate user review action; the red button nudges but does not auto-close.

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.

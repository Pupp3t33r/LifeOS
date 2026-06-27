# ADR-0027: Early payment of a future-period occurrence

## Status

Accepted

Date: 2026-06-28

**Amends:**

- [ADR-0016](./0016-accounting-period-flow-ledger.md) — `AccountingPeriod` gains two new event types: `OccurrencePaidInAdvance` and `OccurrencePaidInAdvanceRetracted` (status-reference markers, not actuals).
- [ADR-0017](./0017-recurring-payment-rules-and-schedules.md) — early-payment is a new confirm variant; occurrence status for an early-paid occurrence is **marked locally on the occurrence's own period** (a bounded, partial reversal of 0017's "derive purely by join" stance), and the cross-period idempotency check is replaced by **stream-enforced idempotency** on the occurrence's period stream.
- [ADR-0023](./0023-active-month-model.md) — a named exception to "future periods accept planning operations only": an `OccurrencePaidInAdvance` status marker may be written to a future period **atomically with the paying actual** (the same door ADR-0020 opened for carry-make-up). Future periods still reject actuals and close.

**Relates to:**

- [ADR-0020](./0020-recurring-live-carry-make-up-defer.md) — the precedent for writing to the next/future period atomically in one Marten transaction.
- [ADR-0026](./0026-actuals-honesty-and-savings-movements.md) — the actuals fold definition (only `FlowRecorded`/`FlowReverted`/`UnaccountedFlowRecorded` sum into actuals); the marker is deliberately excluded.
- [ADR-0018](./0018-planned-purchases-on-accounting-period.md) — the same early-pay pattern generalizes to planned purchases (a future-period `PlannedPurchaseAdded` paid early) but is scoped to recurring for v1.

## Context

ADR-0017 tracks recurring-occurrence state **by join**: confirmations (`FlowRecorded`) and skips (`OccurrenceSkipped`) on the `AccountingPeriod` stream carry a back-reference `{ recurringId, occurrenceRef }`, and the `RecurringScheduleProjection` derives each occurrence's status (`projected` / `paid` / `skipped`) by joining computed/listed occurrences against those references. Crucially, 0017 scoped both the join and the "already confirmed?" idempotency check to **within one period**, on the assumption that "an occurrence maps to exactly one period by its date, so there is no cross-period write or scan."

**Early payment breaks that assumption.** The user wants to pay a future-period occurrence from the current period — e.g., pay **July's rent** (Live, DueDate July 1) on **June 28**, or settle **July's installment line** (Materialized, `LineId L7`) in June. Per ADR-0016, the `FlowRecorded` lands in the period of its **actual date — June** (correctly), carrying the back-ref `{ recurringId, occurrenceRef: <July's key> }`. So the occurrence *belongs to* July, but the payment lives in June. Two gaps result:

1. **July cannot derive "my rent is paid" from its own stream** — the `FlowRecorded` is in June. Under 0017's within-period join, July would still show its rent as `projected` (unpaid).
2. **The "already confirmed?" idempotency check**, scoped within one period, cannot see June's payment from July — so July could re-confirm its rent (double-pay).

The straightforward fix — widen the join and the idempotency check to scan **all** periods for the recurring's back-refs — works (the `occurrenceRef` is already a global key), but it makes occurrence status **non-local** (July must query other periods) and leaves idempotency as a **best-effort pre-write query** with a real race window (two concurrent early-pays from different periods both succeed before either sees the other).

Forces at play:

- The system favors **period-local state** (ADR-0016 put flows on the period for exactly this reason). A cross-period scan on every status read cuts against that.
- The back-reference already globally identifies an occurrence; the *data* to mark July's rent paid exists — it is just in the "wrong" period.
- ADR-0020 already established that a future period may be written **atomically** within a Marten transaction that also writes the current period (carry-make-up), and ADR-0023 blessed that door. Early payment is a sibling case.
- Idempotency for a concurrently-risky operation is strongest when enforced by **stream concurrency** (a single contention point), not by a pre-write read.

## Decision

### Two events, two streams, one atomic transaction

Paying a future-period occurrence early appends **two events in one Marten transaction** (intra-Money atomicity, ADR-0005 — the same pattern as ADR-0020):

| Stream | Event |
|---|---|
| **paying period** (the actual date's period, e.g. June) — ADR-0016 | `FlowRecorded { Amount, OccurredAt, BackRef { recurringId, occurrenceRef }, Lines, … }` |
| **occurrence's period** (the occurrence's own period, e.g. July) | `OccurrencePaidInAdvance { recurringId, occurrenceRef, paidInPeriod, paidEntryId, Amount, RecordedAt }` |

The marker is a **status reference**, not an actual:

```
OccurrencePaidInAdvance {
  recurringId,    // which recurring
  occurrenceRef,  // which occurrence — LineId (Materialized) or DueDate (Live), the global key
  paidInPeriod:   (Year, Month),  // where the actual lives (ref part 1)
  paidEntryId:    Guid,           // the FlowRecorded's EntryId (ref part 2)
  Amount:         CurrencyAmount, // the actual paid amount (DISPLAY ONLY — see below)
  RecordedAt,
}
```

### The marker's amount is display-only — it never reaches actuals

Per [ADR-0026](./0026-actuals-honesty-and-savings-movements.md), the actuals fold in `MonthProjection` sums **only** `FlowRecorded` + `UnaccountedFlowRecorded` − `FlowReverted`. The `OccurrencePaidInAdvance` event type has **no handler in the actuals fold** — it binds to the *occurrence-status/display fold* instead. So July's `Σ flows` / savings / close is **untouched** by the marker; the $1,000 lives exactly once, in June. The amount on the marker is for **display** ("Rent $1,000 — paid in advance") and is read locally from July's own stream, with no pointer-chase into June.

This is the typed-fold guarantee: an amount only reaches a fold if that fold has a handler for the event type. The marker's amount is safe because the actuals fold does not read it.

### Period-local reads

An occurrence's status is now fully derivable from **its own period's stream**:

- a `FlowRecorded` back-ref → a normal **on-time** confirm (paid in-period), or
- an `OccurrencePaidInAdvance` marker → an **early** confirm (paid in another period).

July never queries other periods to learn its rent's status. This is the locality property that drove the two-event design.

### Strong idempotency via stream concurrency

Because the marker appends to the **occurrence's period stream**, Marten's optimistic concurrency makes that stream the single contention point for the occurrence's "paid" status:

- **Normal double-confirm (within July):** the existing within-period check on the period aggregate (ADR-0017) catches it.
- **Early double-confirm (two concurrent early-pays from different periods):** both transactions try to append `OccurrencePaidInAdvance` for the same `occurrenceRef` to **July's** stream. One wins; the other gets a Marten `ConcurrencyException` and **rolls back entirely** — including its paying-period `FlowRecorded`. No partial state, no double-pay.

This replaces 0017's within-period-only idempotency (which early payment broke) with a **stream-enforced invariant** for the early case — strictly stronger than the best-effort cross-period scan.

### Revert / correction

If the paying-period `FlowRecorded` is reverted (`FlowReverted`), a compensating **`OccurrencePaidInAdvanceRetracted`** is appended to the occurrence's period **in the same transaction**. A correction (revert + re-record a different amount) retracts the old marker and writes a new one (fresh `paidEntryId`/`Amount`), so the marker stays current with the actual.

### Scope

- **Live occurrences** (`occurrenceRef` = DueDate) and **Materialized lines** (`occurrenceRef` = LineId) both support early payment — identical mechanism.
- **No artificial window** on how far ahead an occurrence may be paid (user-driven).
- **Generalizes** to paying a planned purchase early (a future-period `PlannedPurchaseAdded` paid in the current period via a `FlowRecorded { PlannedEntryId }` back-ref + an equivalent future-period marker), per ADR-0018's back-ref pattern. v1 implements the recurring case (the forcing function); the planned-purchase case reuses the same pattern if needed.

### ADR-0023 exception (future-period write)

Future periods accept **planning operations only** (ADR-0023). `OccurrencePaidInAdvance` is neither planning nor an actual nor close — it is a **status reference**. ADR-0023 is amended with a named exception: an occurrence-status marker may be written to a future period **atomically with the paying actual**, exactly as ADR-0020's carry-make-up writes a `PlannedPurchaseAdded` to the next period. Future periods still reject actuals (`FlowRecorded`) and close (`MonthClosed`); only this one marker type is permitted.

The early payment itself is an **actual in the paying (current) period** — routed by date per ADR-0016 — never a write to the future period's actuals.

## Consequences

Positive:

- Occurrence status is **period-local** — each period reads its own stream; no cross-period scan.
- Early-payment idempotency is **stream-enforced** (Marten concurrency on the occurrence's period) — strictly stronger than a best-effort query, with no race window.
- The actuals ledger is **unaffected**: the marker is display-only; `Σ flows` and balances are correct. No double-count.
- Reuses the atomic two-stream write pattern ADR-0020 established; ADR-0023's future-period door is already open.

Negative:

- Two events instead of one; a compensating `Retracted` event on revert/correction (explicit bookkeeping that a pure-join approach would handle implicitly).
- A bounded, partial reversal of ADR-0017's "derive purely by join, no markers" stance — markers now exist for the early-pay case (only). Accepted: the marker is a *forwarding reference*, not a status duplicate, and it is bounded to early-paid occurrences (normal confirms remain in-period `FlowRecorded`, read locally).
- Amends three frozen ADRs (0016, 0017, 0023). All pre-implementation, so refactor cost is zero.

Neutral:

- The `OccurrencePaidInAdvanceRetracted` event mirrors `FlowReverted`'s role for the marker; the projection treats retraction symmetrically.

## Alternatives Considered

1. **Single event + cross-period join (widen ADR-0017's join to all periods).** Rejected: makes occurrence status non-local (every status read scans other periods) and leaves idempotency as a best-effort pre-write query with a real race window (two concurrent early-pays both succeed before either sees the other). The two-event model gives locality and stream-enforced idempotency instead.
2. **Denormalized `RecurringStatusProjection` (a maintained per-occurrence status map across all periods).** Rejected for v1: new write-side infrastructure, eventually-consistent (so it cannot power write-side idempotency without a separate strong index), and it does not give period-locality as cleanly as the marker on the period stream. Documented as a scale-out read optimization if cross-period reads ever prove costly.
3. **Hard synchronous confirmed-occurrence index on the recurring stream (`OccurrenceConfirmed` events folded into a set).** Rejected: reintroduces the unbounded per-occurrence state on the recurring aggregate that ADR-0017 deliberately removed (especially problematic for Live series); also non-local to the period. The period-stream marker gives the same strong guarantee without touching the recurring aggregate.
4. **Marker with no amount (pure pointer; display follows `paidEntryId` to the paying period).** Rejected: defeats the locality win for display (July would reach into June to show the amount) for a defensive measure against our own projection bug. The typed-fold model already guarantees the marker's amount cannot reach the actuals fold; carrying it is safe and keeps July fully local.
5. **Forbid early payment (force on-time only).** Rejected: a real user need (pay July's rent in June; settle an installment early), explicitly identified as deferred work in ADR-0023.

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.

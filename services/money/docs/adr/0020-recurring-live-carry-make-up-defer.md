# ADR-0020: Recurring Live carry-make-up defer

## Status

Accepted

Date: 2026-06-27

**Amends:**

- [ADR-0017](./0017-recurring-payment-rules-and-schedules.md) — a Live recurring occurrence gains a third defer operation: **carry-make-up** (skip + a disconnected one-off next period). Materialized defer (re-date the line) is unchanged.

**Relates to:** [ADR-0018](./0018-planned-purchases-on-accounting-period.md) (`PlannedPurchaseAdded` and its `Origin` soft-reference field), [ADR-0016](./0016-accounting-period-flow-ledger.md) (`OccurrenceSkipped`, `FlowRecorded`).

## Context

ADR-0017 defines two fates for an unpaid Live occurrence: **skip** (`OccurrenceSkipped` — move on, no arrears) and **cancel** (the whole series terminal). Materialized lines additionally support **re-dating** (move the line forward).

Skip is correct for the ~90% case where missing a month leaves no arrears — a skipped salary occurrence is simply unpaid; a skipped subscription is simply not-paid-this-month. But for **arrears-creating recurring** (rent, debt-like obligations), skipping abandons an amount the user still owes. The user needs a way to say: "I didn't pay March's rent; I'll pay it in April **on top of** April's regular rent" — i.e., carry the unpaid amount forward as a make-up, *without* it being a real recurring occurrence (April's regular occurrence still fires from the rule).

Creating this make-up as a real recurring occurrence is wrong: the rule generates April's occurrence independently, so duplicating it would double-count or desync the schedule. The make-up is a **one-off** — a disconnected planned purchase that references the recurring in name only, for display and audit.

## Decision

### Live carry-make-up: skip + a disconnected one-off next period

A new composite operation on an unpaid Live occurrence: **carry-make-up**. It appends, in **one Marten transaction** (intra-Money atomicity, ADR-0005):

1. `OccurrenceSkipped` on the **current** period, with back-ref `{ recurringId, occurrenceRef: <due date> }` — records that the occurrence was not paid in its period.
2. `PlannedPurchaseAdded` on the **next** period, carrying:
   - `Origin: { RecurringId, CarriedFromDate: <due date> }` — the soft reference defined in [ADR-0018](./0018-planned-purchases-on-accounting-period.md),
   - `Lines` with the unpaid amount (the make-up),
   - optionally the recurring's `Category` and description, derived for display.

The make-up entry is a **disconnected one-off**: mechanically a normal planned purchase on the period stream — cancellable, editable, payable like any other — referencing the recurring only via `Origin` for naming and audit ("Rent arrears — from March"). It is **not** a recurring occurrence and does not affect the rule or the recurring aggregate.

### Resulting projection

The next period's canvas shows **two** entries for the recurring: the regular occurrence (computed from the rule) and the make-up one-off (the carried `PlannedPurchaseAdded`). Both are independently confirmable. The user owes both.

### Disambiguating skip from carry-make-up

A **pure skip** (abandon, no arrears) is an `OccurrenceSkipped` with **no** corresponding `PlannedPurchaseAdded.Origin` pointing at it. A **carry-make-up** is an `OccurrenceSkipped` **with** a next-period `PlannedPurchaseAdded.Origin` referencing it. The projection derives the distinction by join; **no separate marker event is needed**.

### Materialized is unchanged

Materialized defer remains **re-date the line forward** (`ScheduleLineEdited`), per ADR-0017 — the line is the unit, and moving it is cleaner than skip + make-up. Carry-make-up is **Live-only**.

## Consequences

Positive:

- Arrears-creating recurring (rent, debt) gain an honest make-up path without desyncing the schedule or double-counting the rule's next occurrence.
- The make-up is a first-class planned purchase (cancellable/editable/payable), reusing the period-centric model of ADR-0018.
- No new marker event — the skip + `Origin` join derives everything.

Negative:

- A composite operation spanning two period streams (current + next). Appended in one Marten transaction so the skip and the make-up appear together (no partial state).
- Slightly more complex projection (join `Origin` back to the skipped occurrence to distinguish skip vs carry-make-up). Acceptable.

Neutral:

- The make-up entry's amount defaults to the unpaid occurrence's estimated amount; the user can edit it (the actual paid may differ), consistent with ADR-0017's "actual adjustable at confirm."

## Alternatives Considered

1. **Pure skip only (no carry-make-up).** Rejected: abandons arrears for rent/debt-like recurring; the user has no honest way to carry an unpaid amount forward.
2. **Make the make-up a real recurring occurrence.** Rejected: the rule independently generates the next occurrence; duplicating it double-counts or desyncs the cadence. The make-up is conceptually a one-off, not part of the schedule.
3. **A separate `OccurrenceCarried` marker event.** Rejected: the `Origin` soft-ref on the next-period `PlannedPurchaseAdded` already distinguishes carry-make-up from pure skip by join. A dedicated marker duplicates that information.
4. **Re-date for Live too (like Materialized).** Rejected: Live occurrences are *computed* from the rule, not stored; there is no line to re-date. Supporting it would force per-occurrence exceptions in the rule, which ADR-0017 deliberately avoided.

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.

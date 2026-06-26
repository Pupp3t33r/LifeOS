# ADR-0017: RecurringPayment — recurrence-rule hierarchy, two schedule modes, period-tracked occurrences

## Status

Accepted

Date: 2026-06-26

**Supersedes:**
- The **`InstallmentPlan` aggregate** of [ADR-0005](./0005-aggregate-boundaries.md). Installments collapse into `RecurringPayment` (no separate `installment/{…}` stream).
- The part of ADR-0005's `RecurringPayment` row stating it "tracks the transaction IDs it produced." With [ADR-0016](./0016-accounting-period-flow-ledger.md) the link is inverted: confirmations (`FlowRecorded`) on the AccountingPeriod stream carry a back-reference to the recurring payment; the recurring aggregate stores no per-occurrence state.
- The detail of [ADR-0016](./0016-accounting-period-flow-ledger.md) §Endpoints that confirming a recurring line appends a `LineConfirmed` event to the recurring stream. Confirmation writes **only** `FlowRecorded` (with the back-reference) to AccountingPeriod; the recurring stream is not written on confirm.

**Relates to:** ADR-0016 (flow ledger), ADR-0008/0015 (`CurrencyAmount`, FX), ADR-0007/0016 (`MonthProjection`), ADR-0013 (period mapping).

## Context

ADR-0005 defined a `RecurringPayment` aggregate and a separate, deferred `InstallmentPlan`, leaving open whether an installment is its own aggregate or "a RecurringPayment with an end date + progress." Three real-world archetypes set the requirements:

1. **Salary** — open-ended, paid in two tranches per month.
2. **Debt** — a fixed number of payments; prepaying triggers the *lender* to recalculate the remaining schedule.
3. **Installments / pre-orders** — a fixed number of payments on regular *or* arbitrary (bookkeeper-set) dates; paying ahead settles a line with no recalculation.

These differ only on: end (indefinite vs fixed count), payments per cycle, schedule regularity (rule vs arbitrary dates), and prepay behavior. Everything else (direction, currency, tags, confirm) is identical — so one aggregate with a couple of knobs fits all three.

Cron expressions were considered and rejected: standard cron cannot express "every 20 days" (it resets monthly) or bi-weekly (no cross-week interval), has no count/end, and carries cross-implementation parity risk between the .NET server and the Dart client. A small structured rule is strictly more expressive here and is trivially identical across both languages.

ADR-0016 moved actuals onto the per-period AccountingPeriod stream. That is what lets `RecurringPayment` avoid storing any per-occurrence state — solving how to represent an *unbounded* series.

## Decision

### One aggregate, two schedule modes (collapses InstallmentPlan)

`RecurringPayment` (stream `recurring/{RecurringPaymentId}`, `OwnerId`-scoped) holds **definition + lifecycle only — no per-occurrence state**:

- Header: name, direction (`in`/`out`), the savings/source context, single `CurrencyAmount` currency, tags.
- A **schedule** in one of two modes:
  - **Live** — a recurrence `Rule`; occurrences are *computed*, never stored. Used for salary, rent, subscriptions.
  - **Materialized** — a finite, editable list of `ScheduleLine { LineId, DueDate, ExpectedAmount }` with a known total; used for debt, installments, pre-orders. An installment is simply a RecurringPayment in this mode.
- `Status`: `Active`, `Cancelled` (terminal).

### Recurrence rule — discriminated hierarchy

```
abstract RecurrenceRule { DateOnly Start; RecurrenceEnd End; }
  DailyRule   { int IntervalDays; }                                  // every 20 days
  WeeklyRule  { int IntervalWeeks;  ISet<DayOfWeek> Weekdays; }      // every Mon / bi-weekly Fri
  MonthlyRule { int IntervalMonths; ISet<MonthDayAnchor> Days; }     // 1st & 15th / last day / quarterly
  YearlyRule  { int IntervalYears;  ISet<AnnualDate> Dates; }        // annual

abstract RecurrenceEnd;  NeverEnds | EndsOnDate(DateOnly) | EndsAfter(int Count)
abstract MonthDayAnchor; OnDayOfMonth(int 1..31, clamped) | LastDayOfMonth
record AnnualDate(int Month, int Day)
```

Serialized as a **discriminated JSON union** (`kind` discriminator, System.Text.Json `[JsonPolymorphic]`/`[JsonDerivedType]`) inside events; mirrored as **Dart sealed classes** on the client with the same discriminator, so the estimate side and the authoritative side are structurally identical. Generation is an exhaustive `switch` over the subtypes — no per-unit null checks. Dates are `DateOnly` (no time/DST); `Start` fixes parity; day-of-month past a month's length clamps to the last day (consistent with ADR-0013). `nth weekday of month` ("first Monday") is a clean future subtype, deferred from v1.

### Materialized schedule — arbitrary dates fall out for free

A Materialized schedule is a stored list of self-describing lines, authored three ways: rule-seeded then edited, fully manual (the bookkeeper's arbitrary dates), or hybrid. Lines (unconfirmed only) are freely added/edited/removed. The total is Σ line amounts; progress is derived. There is no amortization engine — the **debt-reschedule after a prepayment is the user editing the remaining lines** to the lender's authoritative figures (the honesty-valve pattern). Installment prepay = confirming a future line; the rest are untouched.

### Occurrences are tracked on AccountingPeriod, not here

The recurring aggregate stores no occurrence status. For the **active period only** (consistent with the active-month model — past/future periods are not edited here):

- **Confirm** → `FlowRecorded` on the AccountingPeriod stream (ADR-0016), carrying a back-reference `{ recurringId, occurrenceRef }` where `occurrenceRef` is the `LineId` (Materialized) or the occurrence `DueDate` (Live). The actual amount and date are adjustable at confirm time (the confirm dialog) and may differ from the scheduled/expected amount; the schedule is unchanged. Confirmation is **user-driven only — recurring never auto-posts.**
- **Skip** → an `OccurrenceSkipped` marker on the AccountingPeriod with the same back-reference.
- **Un-confirm / correct** → `FlowReverted` (ADR-0016); an amount correction is reverse + re-record.

Idempotency ("already confirmed this occurrence?") is a check within that one period (an occurrence maps to exactly one period by its date), so there is no cross-period write or scan. The **projection joins** computed/listed occurrences against the period's references to derive each occurrence's state (`projected` / `paid` / `skipped`) and overall progress.

### Rule edits — in-place, forward-only

Editing a Live rule emits `RuleChanged`: occurrences due on/after the effective date use the new rule; **confirmed actuals on the ledger are immutable and unaffected** (they store their own amounts and reference the stable `recurringId`; full rule history is recoverable by replaying the recurring stream). No dated rule-timeline is needed. Editing a Materialized schedule emits `ScheduleLineAdded/Edited/Removed` on unconfirmed lines. For a genuine "different arrangement," the UI offers **Cancel + clone** (clone pre-fills a create form) rather than mutating in place.

### Lifecycle

- **Active → Cancelled** (explicit, terminal) — future occurrences stop surfacing.
- **Completed** is a *derived display state* (all scheduled lines confirmed/skipped, or a Live rule reached its `End`), not an authoritative event.
- **No pause/resume** — Cancel + clone covers it.
- **Cancel may record an optional reimbursement** — a fresh `FlowRecorded`(direction `in`) on the active period for the real (user-entered) refund. This is **not** a reversal of past payments: you paid, then genuinely got money back; both are facts in the timeline.
- **Delete** is allowed only when no occurrence was ever confirmed (mistake cleanup); otherwise Cancel.

### Events (recurring stream)

`RecurringPaymentCreated`, `RuleChanged`, `ScheduleLineAdded`, `ScheduleLineEdited`, `ScheduleLineRemoved`, `RecurringPaymentEdited` (name/tags/context), `Cancelled`. No per-occurrence events, no pause events.

### Currency and subscriptions

One `CurrencyAmount` currency per recurring payment (like accounts); cross-currency display/conversion per ADR-0008/0015. A **subscription is a tagged recurring payment**, not a distinct concept; tag storage rides on the deferred tag-storage decision (ADR README).

## Consequences

Positive:

- One aggregate covers salary, debt, and installments; the InstallmentPlan stream disappears.
- The aggregate never stores an instance list, so an unbounded Live series is a non-problem; the recurring stream stays small (definition + a few lifecycle events).
- Occurrence state lives once, on AccountingPeriod, with the projection joining — no duplicated status, no cross-period writes.
- In-place forward rule edits are safe because actuals are frozen on the ledger; "rent" is not fragmented into many records on every change.
- Arbitrary-date schedules and debt reschedules need zero special machinery — they are ordinary edits to a materialized line list.

Negative:

- Progress and "completed" are derived (projection), not write-side invariants. Acceptable: the only write-side check needed (no double-confirm) is local to one period.
- Determining an occurrence's status requires the projection to compute rule occurrences and join period references, rather than reading a stored line status.
- The client must mirror the rule hierarchy and the occurrence-join logic to render projected-vs-paid; covered by shared serialization + parity tests.

Neutral:

- The recurrence rule is a small structured type we own on both sides, not an external cron/RRULE dependency.

## Alternatives Considered

1. **Separate `InstallmentPlan` aggregate (ADR-0005).** Rejected: identical line/confirm logic; one aggregate with two schedule modes is simpler.
2. **Store an instance/line-status list on the recurring aggregate.** Rejected: unbounded for Live series, and it duplicates status that AccountingPeriod already holds.
3. **Cron expressions for the rule.** Rejected: cannot express every-N-days or bi-weekly, has no count, and risks server/client parity divergence.
4. **Dated rule-timeline (versioned rules).** Rejected as overkill: in-place forward edits suffice because actuals are frozen on the ledger and rule history is in the event stream.
5. **Pause/resume.** Rejected: Cancel + clone is simpler and covers the real need.
6. **A recalculation engine for debt prepayment.** Rejected: we cannot replicate a lender's interest math (false precision); editable schedule lines with user-entered figures are honest and simpler.

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.

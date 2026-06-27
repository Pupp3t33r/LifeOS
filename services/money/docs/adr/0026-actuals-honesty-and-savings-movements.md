# ADR-0026: Actuals honesty & savings movements

## Status

Accepted

Date: 2026-06-28

**Amends:**

- [ADR-0007](./0007-monthly-review-and-projection.md) — **removes** `ActualSavingsOverride` (the field), the `ActualSavingsOverridden` event, and the close formula `final = ActualSavingsOverride ?? projectedSavings`. The honesty valve is re-modeled as a flow entry (this ADR). `TargetSavings`, `MonthOpened`, `TargetSavingsSet`, `MonthClosed`, `ClosingFxRates`, and the lock/close ceremony stand.
- [ADR-0021](./0021-close-flow-multi-account-allocation-and-dispositions.md) — the deferred sub-question **"`ActualSavingsOverride` vs allocations"** is **closed by elimination**: there is no override; actual = Σ flows, and allocations distribute that sum. The "dipping into savings for a purchase" sub-question is resolved **close-time aggregate only** (no mid-month per-purchase withdrawals) — see Decision.

**Relates to:**

- [ADR-0016](./0016-accounting-period-flow-ledger.md) / [ADR-0019](./0019-universal-line-items.md) — flows live on `AccountingPeriod`; the new event joins them.
- [ADR-0009](./0009-savings-accounts-and-month-close.md) — savings-account balance changes via movements; this ADR names that event.
- [ADR-0008](./0008-multi-currency-and-fx.md) / [ADR-0015](./0015-fx-rate-sourcing-and-client-cache.md) — `CurrencyAmount`, close-day FX.
- [ADR-0003](./0003-idempotency-via-client-assigned-uuids.md) — `EntryId` idempotency on the period.

## Context

ADR-0007 introduced `ActualSavingsOverride` as the planner's honesty valve: a single user-entered number per period ("in reality I saved $X") that, when set, replaces the computed projection at close via `final = override ?? projectedSavings`. The motivation was sound — the planner tolerates gaps in transaction logging (untracked coffees, cash) — but the *mechanism* is wrong for an event-sourced ledger:

- The override is a **god-number** that *replaces* the flow ledger's result. When `override != Σ logged flows`, the `FlowRecorded` entries no longer sum to actual, and the difference is a silent, unexplained gap. That **invalidates the ledger's completeness** — the central property event sourcing is meant to guarantee.
- ADR-0021 then introduced **allocations** (user-chosen, multi-account, not validated) as the close-time realization of savings. With both an override and allocations, two "actual savings" signals compete, and the relationship (`final = override ?? projected` vs `Σ allocations`) is unsettled — captured as a deferred sub-question in ADR-0021.

Separately, ADR-0016 narrowed Account streams to **savings movements only** and ADR-0021's close flow writes allocation movements — but the movement event itself was never formally named; the old generic `TransactionRecorded` (ADR-0005) is now misleading, since everyday transactions are `FlowRecorded` on the period.

Forces at play:

- Every cent of "actual" should be **accounted for by a flow entry** — the ledger must sum to actual, always.
- The honesty-valve UX ("I know I actually saved $X") must be preserved; only the storage changes.
- "Dipping into savings for a purchase" (a purchase the period's income cannot fully cover) already happens via the close deficit withdrawal (ADR-0021); the question is whether a *per-purchase, mid-month* withdrawal is also needed.
- A savings movement (deposit/withdraw) is the mechanism the close flow and any manual balance adjustment use; it needs a name and shape.

## Decision

### 1. Drop the override god-number; model the honesty valve as a flow entry

`ActualSavingsOverride` (field), `ActualSavingsOverridden` (event), and the formula `final = override ?? projected` are **removed**. In their place, a new **sibling event on the `AccountingPeriod` stream** represents *the gap*:

```
UnaccountedFlowRecorded {
  OwnerId, (Year, Month),   // the period stream (implied by the stream key)
  EntryId:    Guid,          // ADR-0003 idempotency; rides the period's EntryId invariant
  Amount:     CurrencyAmount,// the gap, signed, in the DISPLAY currency
                             //   negative = unaccounted spending (actual < projected)
                             //   positive = unaccounted income    (actual > projected)
  OccurredAt, RecordedAt,
  Notes?:     string,        // "untracked coffees", "cash spending"
}
```

The gap entry is a **single signed number** (not itemized — you do not categorize "unaccounted" into coffee/groceries; it is just "the stuff I didn't log"), in the display currency, with **no lines and no `CategoryId`**. It is its own event type (not a flagged `FlowRecorded`) so that its nature ("this is the adjustment, not a real transaction") is explicit and the multi-line `FlowRecorded` event stays unpolluted.

**Actual is now always the sum of flow entries:**

```
actual = Σ FlowRecorded line amounts
       − Σ FlowReverted
       + Σ UnaccountedFlowRecorded.Amount        (all in display currency; flows at event-time FX per ADR-0015)
```

The ledger is **complete and consistent** — every cent of actual is a flow entry. The honesty-valve UX is preserved: the screen may still say *"set actual savings to $800"*; under the hood the system records/updates the gap entry (projected − $800). The user never sees event sourcing being bypassed.

### 2. Close flow simplified (resolves ADR-0021's override sub-question by elimination)

There is no override, so there is no `final = override ?? projected`. The close flow becomes:

1. Append `MonthClosed` (captures `ClosedAt`, `ClosingFxRates`) — unchanged.
2. **actual = Σ flows** (read from `MonthProjection`).
3. The user **allocates actual across one or more savings accounts** (ADR-0021); each allocation becomes a `SavingsMovementRecorded(Source = close)` (below) on the target account's stream, converted to that account's currency at `ClosingFxRates`.
4. **Σ allocations (display currency) = actual.** No competing truth source.

Mid-period, the canvas shows `actual` (= Σ flows so far, including any gap entry) alongside `projected`; the user adds/edits a gap entry to make `actual` honest. The override-vs-allocations tension is gone — they were never two truths, just a broken god-number and the real mechanism (flows + allocations).

### 3. Dipping into savings = close-time aggregate only (resolves ADR-0021's dipping sub-question)

A purchase that exceeds the period's income is funded from savings **at close, via the deficit allocation** — the mechanism already exists (ADR-0021). Example: a period with income $4,000 and $4,800 of expenses (incl. an $1,800 lens) nets **−$800**; at close the user chooses which account(s) absorb the $800 deficit, and an $800 `SavingsMovementRecorded(Source = close)` withdrawal lands there. The canvas shows the dip all period (projected/actual goes negative or below target).

- **No mid-month, per-purchase "fund from savings" withdrawals** in v1. The savings balance moves only at close (deficit/surplus) and via explicit manual movements. The account balance does not reflect the lens the moment it is logged — only at close.
- An opt-in per-purchase mid-month withdrawal (an *advance* of the close deficit, netted at close) is a **deferred enhancement**, not v1. Rationale: it adds a reconciliation step in the close handler and a per-purchase linkage, for a benefit (instant balance reflection) that is at odds with the planner's deliberate de-emphasis of real-time balance (ADR-0009). The dip is fully visible on the canvas and fully realized at close.

### 4. The `SavingsMovementRecorded` event (names the mechanism ADR-0021 assumed)

The generic `TransactionRecorded` on Account (ADR-0005) is **superseded** by a savings-movement-specific event. Account streams carry `AccountOpened` + `SavingsMovementRecorded` (+ lifecycle events per a future accounts ADR):

```
SavingsMovementRecorded {
  AccountId,
  MovementId:  Guid,           // client-assigned; ADR-0003 idempotency on the account stream
  Amount:      CurrencyAmount, // signed, in the ACCOUNT's currency (+ deposit, − withdrawal)
  OccurredAt, RecordedAt,
  Source:      manual | close, // what produced this movement
  TransferId?: Guid,           // RESERVED for the deferred transfers feature (ADR-0009); unused in v1
  Description?: string,
  FxRate?:     decimal,        // present on close allocations (display→account conversion at ClosingFxRates);
                               // absent on manual single-currency moves
}
```

- `Source = manual` — a deliberate deposit/withdraw the user makes.
- `Source = close` — a close-flow allocation (surplus deposit or deficit withdrawal, ADR-0021).
- `TransferId` is reserved for transfers (two linked movements, ADR-0009), which remain **deferred** — when transfers land, they are simply two `SavingsMovementRecorded` entries sharing a `TransferId`, written atomically in one Marten transaction.
- Account balance = `OpeningBalance + Σ movements` (the fold ADR-0009 already described, now over a named event). Accounts remain balance-bearing, single-currency aggregates; everyday flows never post to them (ADR-0016).

### 5. Variance — a computed field, no new state

`variance = actual − projected` is computed in `MonthProjection` and surfaced on the canvas / closed-period view ("Projected $1,000, Actual $950, −$50"). Because the gap entry is part of `actual`, variance cleanly quantifies the real divergence (logged + unaccounted) from the plan. No new stored state.

## Consequences

Positive:

- The flow ledger is **complete**: actual = Σ flows, always. No god-number bypasses the ledger; event-sourcing integrity is restored.
- The override-vs-allocations tension (ADR-0021 deferred) **dissolves** — there is no override.
- The honesty-valve UX is preserved (user sets actual); only the storage is honest now.
- Close flow simplifies (no `override ?? projected` branch); actual = Σ flows, allocated across accounts.
- The savings-movement event finally has a name and shape, retiring the misleading generic `TransactionRecorded` on Account.
- Dipping works today (close deficit) with no new machinery.

Negative:

- Amends ADR-0007 (removes override field/event/formula) and touches the close-flow wording of ADR-0021. Both pre-implementation, so refactor cost is zero.
- A new event type (`UnaccountedFlowRecorded`) and a renamed Account event (`SavingsMovementRecorded`) — the young Transactions feature is refactored.
- Mid-month per-purchase funding is deferred (documented), so the savings balance does not reflect a big purchase until close. Accepted for v1 (planner philosophy).

Neutral:

- `apps/wallet/PLAN.md` §2's "actual savings (override)" layer and the AGENTS "honesty valves" wording both reword to "actual savings (Σ flows incl. adjustment)."

## Alternatives Considered

1. **Keep `ActualSavingsOverride` (ADR-0007 as-is).** Rejected: a god-number that replaces the ledger's result invalidates the completeness guarantee of event sourcing — the central defect this ADR fixes.
2. **Model the gap as a `FlowRecorded` with `Kind = Adjustment` (flagged).** Rejected: pollutes the multi-line real-transaction event with a marker, and conflates "the gap" (one signed number, no lines/category) with a real flow. A dedicated sibling event matches the gap's nature and keeps `FlowRecorded` clean.
3. **Model the gap as a system "Unaccounted" category on a normal `FlowRecorded`.** Rejected: "unaccounted" is not a budgeting category (you do not budget for it); categories are for budgets/filtering. The gap is an entry *kind*, not a category.
4. **Mid-month per-purchase "fund from savings" withdrawals (advance of the deficit).** Rejected for v1: adds close-handler reconciliation and per-purchase linkage for a benefit at odds with the planner's de-emphasis of real-time balance. Close-time aggregate funding already works (ADR-0021). Deferred as an enhancement.
5. **Keep a separate post-close override alongside allocations ("estimated vs actually moved").** Rejected: allocations are the truth; a second number is noise. Variance (`actual − projected`) already communicates the estimate-vs-reality gap honestly.

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.

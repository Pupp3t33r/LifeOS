# ADR-0013: UserPreferences — configurable month start day and display currency

## Status

Accepted

Date: 2026-06-24

**Amends:** the period-keying of [ADR-0006](./0006-budget-aggregate.md) (Budget) and [ADR-0007](./0007-monthly-review-and-projection.md) (MonthlyReview / MonthProjection). The stream-key *shape* `{Owner}/{Year}/{Month}` is unchanged; this ADR generalizes what `(Year, Month)` *means* from "calendar month" to "the user's configured monthly period." It also revises the "display currency = primary savings account currency" statement in [`apps/wallet/AGENTS.md`](../../../../apps/wallet/AGENTS.md).

## Context

The Wallet app needs a small set of settings configured before its core surface — the monthly savings canvas — can render meaningfully (see `apps/wallet/PLAN.md`). Two of those settings are not app-local preferences; they change numbers the **server** computes, so under the Wallet architecture rule ("no client-side business rules; Money's rules run once, on the server") they must be owned by Money.

Forces at play:

- **Month boundaries were a deferred backend question.** Money `PLAN.md` §7 flags *"User-defined month boundaries (start/end date set by user, not calendar month). Affects Budget (§3.6) and MonthlyReview (§3.7) stream keys — `Year/Month` may need to become a period identifier. Likely amends ADR-0007."* The product decision (2026-06-24) is to support a **user-configurable month start day** (payday-aligned budgeting, e.g. "my month starts on the 25th"), not calendar-only.
- **No home for user-authored configuration exists.** Money has aggregates for accounts, transactions, recurring, installments, wishlist, POs, budgets, and monthly reviews — but nothing holds per-user settings. The month-start day and the display currency have nowhere to live.
- **These settings are config, not ledger facts, and their history is not consumed.** Unlike `MonthlyReview.TargetSavings` / `ActualSavingsOverride` or `Budget.TargetAmount` — whose *values are financial narrative* and whose events the `MonthProjection` composes — nothing in Money reads the *history* of a preference. The only consumer is "what is the current value?" Money already has precedent for storing non-ledger, current-value state outside the event log: ADR-0008 alt #4 keeps FX rates in "a query-optimized projection/table, not the event store" because they "are external observed data, not user-authored domain state." Preferences are user-authored but otherwise the same shape: read-current-only, no projection folds them.
- **Display currency is currently derived, which breaks onboarding bootstrap.** `apps/wallet/AGENTS.md` states *"the display currency equals the user's primary savings account currency."* That makes the canvas's aggregation currency a function of account topology, and undefined on first run before any account exists. The savings canvas (ADR-0007) and budgets (ADR-0006) both denominate in "the user's display currency"; that value needs a definite, settable home.
- **Period identity must stay simple and backward-compatible.** The default (calendar months) must remain the zero-config case, and the existing `(Year, Month)` key shape should not churn — the FX, projection, and close machinery already in flight (Money `PLAN.md` §3.7) keys on it.
- **Identity vs. preferences.** Account identity / PII lives in Keycloak (ADR-0004), not Money. This is financial-app *configuration*, not a user profile — naming should not imply it owns identity.

## Decision

### UserPreferences document

Store per-user configuration as a **Marten document** (`UserPreferences`), **not** an event-sourced aggregate. One document per owner, identified by `OwnerId`, holding current values only:

| Field | Type | Notes |
|---|---|---|
| `OwnerId` | string | Document id. From JWT `sub` (ADR-0004). |
| `MonthStartDay` | int | Day of month a period begins. Range **1–31**, clamped to the month's last day where shorter. Default **1**. |
| `DisplayCurrency` | string? | ISO 4217 code the savings canvas and budgets aggregate into. Null until set (onboarding-incomplete signal). |

Persisted and read via `IDocumentSession` (`Store` / `LoadAsync`), keyed by `OwnerId`. No stream, no events, no fold. This is the one piece of user-authored Money state that is **not** event-sourced — justified because its history is never consumed and it parameterizes financial computation rather than being a ledger fact (see Context and Alternatives).

### Updates and reads

- **Read:** `LoadAsync<UserPreferences>(ownerId)`. If absent, treat as defaults: `MonthStartDay = 1`, `DisplayCurrency = null`. A null `DisplayCurrency` is the canonical "onboarding not yet complete" signal for the Wallet.
- **Write:** upsert the document. Two mutations: set the month start day, and set the display currency. PUT semantics make these naturally idempotent (no ADR-0003 client-UUID dedup needed — there is no append).
- **Onboarding:** the first write (display currency chosen, typically defaulted from the first savings account's currency) creates the document. This is the minimal server state the Wallet must establish before the canvas renders, alongside the first savings account.

### Period semantics (amends ADR-0006 and ADR-0007)

A **period** is identified by `(Year, Month)` — the key shape is unchanged. Its calendar span is generalized:

> Period `(Y, M)` spans `[anchor(Y, M), anchor(next(Y, M)))`, where `anchor(Y, M)` is day `min(MonthStartDay, daysInMonth(Y, M))` of calendar month `M` in year `Y` — the chosen day, or the month's last day when the month is shorter — and `next` is the following calendar month.

Consequences of this definition:

- **`MonthStartDay = 1` ⇒ a period is exactly its calendar month.** The default is fully backward-compatible: every existing ADR-0006/ADR-0007 semantic, stream key, and projection holds unchanged. Calendar months are the special case, not a separate mode.
- The period is **start-anchored**: it is named for the calendar month in which it *begins*. Period `(2026, 3)` with `MonthStartDay = 25` runs **Mar 25 – Apr 24**. (Start-anchoring is required for the `MonthStartDay = 1` degeneracy to be correct; end-anchoring would shift the default by one month — see Alternatives.)
- **The user-facing label is a Wallet concern, not a Money concern.** Money fixes the period *identifier* and its calendar span; whether the Wallet renders period `(2026, 3)` as "March," "Mar 25 – Apr 24," or "the period funded on Mar 25" is a UX decision out of scope here.
- `MonthStartDay` ranges **1–31** and **clamps to the month's last day** when the month is shorter (`min(MonthStartDay, daysInMonth)`): start day 31 anchors on Feb 28/29, Apr 30, etc. This models real "paid on the Nth, or the last day in shorter months" payroll and direct-debit behavior exactly. Because the clamped anchors are still strictly increasing month-over-month, periods always tile cleanly — no gaps, no overlaps — at the cost only of slightly varying period lengths near short months.

The amendment touches only the *meaning* of `(Year, Month)` in:

- `monthly-review/{OwnerId}/{Year}/{Month}` (ADR-0007 stream key).
- `budget/{OwnerId}/{Year}/{Month}/{CategoryKey}` (ADR-0006 stream key).
- `MonthProjection` bucketing (ADR-0007): "a RecurringPayment / InstallmentPlan payment / TransactionRecord falls in month M" now means "its date falls in `[anchor(Y, M), anchor(next))`."

`Account` and `TransactionRecord` are **not** period-scoped (per `PLAN.md` §7) and are unaffected. A transaction's *membership* in a period is computed by the projection from its date; the transaction itself stores no period key.

### Re-anchoring is locked after the first close

A change to `MonthStartDay` is **rejected with 409 if the owner has any `Closed` MonthlyReview** (ADR-0007). Rationale: changing the anchor re-buckets historical dates across period boundaries; allowing it after a close would silently move transactions into or out of locked, audited months and could invalidate a captured close snapshot. The check is a handler-side query over the owner's `MonthlyReview` status — it needs no preference event history. In effect `MonthStartDay` is a setup-time decision. Open (unclosed) periods re-bucket freely because their projections are recomputed on read and nothing is locked. Prospective re-anchoring ("change the start day from period X forward, leaving history intact") is a deferred enhancement, not v1.

### Display currency is explicit, defaulted, and decoupled from the close-target account

`DisplayCurrency` is **stored user-authored state**, not derived from account topology. At onboarding it defaults to the currency of the first savings account opened; thereafter the user may change it independently of how many accounts they hold or which is primary. This supersedes the "display currency equals primary savings account currency" wording in `apps/wallet/AGENTS.md`: the primary account's currency is the **default**, not a live derivation.

This cleanly separates two concerns that prior docs conflated:

- **`DisplayCurrency`** (this ADR) — the currency the canvas and budgets aggregate *into* for readability (ADR-0006, ADR-0007, ADR-0008).
- **The month-close target account** (ADR-0009) — *which* savings account receives the surplus/deficit at close. Still designated per `MonthlyReview`, defaulting to the primary account, in that account's own currency. Unchanged by this ADR.

### Endpoints

Per the Wolverine.Http conventions (ADR-0011), under `Features/UserPreferences/`:

- `GET /api/money/preferences` — returns the current preferences (or defaults if the document is absent). The single call the Wallet makes at startup to learn the period model and display currency.
- `PUT /api/money/preferences/display-currency` — upserts `DisplayCurrency`.
- `PUT /api/money/preferences/month-start-day` — upserts `MonthStartDay`; 409 if any month is closed.

## Consequences

Positive:

- Payday-aligned budgeting is supported without a new key shape or a parallel "mode" — calendar months are `MonthStartDay = 1`, so existing ADR-0006/ADR-0007 code and data need no migration for the default.
- The simplest storage that fits: a Marten document of current values. No stream, no events, no fold, no lazy-init ceremony — read is a load, write is an upsert. Consistent with ADR-0008's precedent of keeping non-ledger state out of the event store.
- The onboarding bootstrap problem is solved: `DisplayCurrency` is a definite, settable value (null until chosen, which doubles as the "onboarding incomplete" signal), defined at first-account creation rather than emerging from account topology.
- Two previously-conflated concerns (canvas display currency vs. close-target account) are cleanly separated.

Negative:

- `MonthProjection` bucketing becomes a date-range computation parameterized by `MonthStartDay` rather than a trivial `(year, month)` match. Modest added complexity in the one projection that consumes six aggregate families.
- No audit trail of preference changes. Accepted: nothing consumes that history, and `MonthStartDay` is locked after the first close anyway, so its mutable window is just setup. If effective-dated preferences are ever needed (see Alternatives #6), that is a deliberate future modeling decision, not a regression.
- Locking the start day after the first close means a user who picks the wrong day and has already closed a month cannot fix it in v1 without an unclose/admin path (not in scope). Mitigation: the Wallet onboarding should make the start-day choice deliberate and explain it is hard to change later.
- Changing `DisplayCurrency` re-denominates open projections (re-converted at current FX per ADR-0008); the canvas figure shifts. This is honest but can surprise — the Wallet should label conversions as "at today's rate" (already an ADR-0008 UI note).

Neutral:

- With a high start day, the clamp makes period lengths uneven near February (e.g. start day 31: the January-anchored period runs Jan 31 – Feb 27, the February-anchored period Feb 28 – Mar 30). The math is unaffected — periods still tile perfectly — but the Wallet may want to surface the actual span rather than just a month name.

- `UserPreferences` is the first non-projection Marten *document* in Money (FX rates per ADR-0008 are the other non-event-sourced store, framed as a projection). The service now has three storage shapes: event streams (aggregates), event-derived projections, and this plain config document.
- Whether a closed month's stored projection re-renders in a newly-chosen `DisplayCurrency`, and at which rates, is left to the close-snapshot semantics of ADR-0007 (the snapshot is authoritative); this ADR does not reconvert history. Flagged as an open implementation detail.

## Alternatives Considered

1. **Calendar months only (no configuration).** Simplest; no new store, no amendment. Rejected by the product decision (2026-06-24): payday-aligned periods are a first-class requirement, not a deferred nicety.
2. **A new opaque `PeriodKey` type replacing `(Year, Month)`.** Cleaner in theory, but churns the stream-key shape across ADR-0006, ADR-0007, the FX/projection machinery already in flight, and any persisted dev data — for no functional gain over generalizing the existing `(Year, Month)` semantics. Rejected: the `MonthStartDay = 1` degeneracy gives backward-compatibility for free; a new key type throws that away.
3. **Event-source `UserPreferences` as an aggregate, like every other user-authored figure.** This was the original draft of this ADR. Rejected: no consumer reads preference *history* (no projection folds it), the `MonthStartDay` audit window is just setup (it locks after the first close), and ADR-0008 already establishes that non-ledger state belongs outside the event store. Event sourcing here buys auditability nobody uses at the cost of a stream, events, and a fold. A document is the right tool.
4. **End-anchored periods** (name the period for the calendar month it ends in — "Feb 25 – Mar 24" = "March"). Matches one common payday intuition ("the paycheck funds next month"), but breaks the `MonthStartDay = 1` degeneracy: it would label `[Feb 1, Mar 1)` as "March," shifting the default off by a month and forcing a migration. Rejected. The funds-month framing is recoverable as a pure Wallet display label without changing the identifier.
5. **Keep display currency derived from the primary account.** Rejected: undefined at onboarding before any account exists, and couples the canvas's readability currency to account topology. Making it explicit (defaulted from the first account) is strictly more flexible and resolves the bootstrap.
6. **Allow free re-anchoring of `MonthStartDay` at any time** (or effective-dated preferences that retain per-period history). Rejected for v1: free re-anchoring silently re-buckets locked, audited closed months. Prospective ("from period X forward") re-anchoring is the safe form; if it lands, it is best modeled as explicit effective-dated rows, not a replayed event log. Deferred until there is a forcing function.
7. **Cap the start day at 1–28 (reject 29–31).** Simpler — every month has the literal anchor day, period lengths are more uniform. This was the original draft. Rejected: it silently denies the very common "paid on the 31st / last day of the month" schedule, while clamping (`min(day, daysInMonth)`) keeps anchors strictly increasing and tiles just as cleanly. The cap buys uniformity nobody needs at the cost of real coverage.

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.
</content>

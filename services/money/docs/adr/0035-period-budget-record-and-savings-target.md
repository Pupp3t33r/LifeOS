# ADR-0035: Budget & savings target — one `PeriodBudget` record per owner per period

## Status

Accepted

Date: 2026-07-10

**Supersedes:**

- The **storage shape** of [ADR-0025](./0025-budget-period-centric-and-category-targeted.md): one `Budget` document **per (owner, period, `CategoryId`)**. This ADR consolidates all of a period's targets into a **single `PeriodBudget` document per (owner, period)** that also carries the savings target and the tracked-category opt-in set. ADR-0025's **`BudgetActuals` projection contract** (per-line grouping, signed sum, event-time FX, `FlowReverted` reversal), its **advisory-only / no-rollover / no-enforcement / does-not-feed-canvas** stance, and its **archived-category resolution** all **stand** and are reaffirmed.

**Amends:**

- [ADR-0007](./0007-monthly-review-and-projection.md) — the monthly **savings target** is persisted as a field on this `PeriodBudget` document, **not** as a `TargetSavingsSet` lifecycle event on `AccountingPeriod`. (The `TargetSavingsSet` event named in Money PLAN §3.7 is not built; this realizes the target-savings concept as document state, consistent with ADR-0013/0022/0025's "user-authored current-state → document" precedent.)
- [Wallet ADR-0005](../../../../apps/wallet/docs/adr/0005-plan-destination-and-planning-views.md) §2 — the Budget view carries a **light period control** (the record is per-period). List and Board stay period-agnostic; only Budget selects a period.

**Relates to:**

- [ADR-0024](./0024-category-model.md) — `CategoryId`, system + user categories; the limit map and tracked set key by it.
- [ADR-0016](./0016-accounting-period-flow-ledger.md) / [ADR-0019](./0019-universal-line-items.md) — `FlowRecorded` lines as the actuals source (`BudgetActuals`).
- [ADR-0013](./0013-user-preferences-and-configurable-month.md) — period scoping; `DisplayCurrency` as the target/limit currency.
- [ADR-0008](./0008-multi-currency-and-fx.md) / [ADR-0015](./0015-fx-rate-sourcing-and-client-cache.md) — `CurrencyAmount`, FX.

## Context

[Wallet ADR-0005](../../../../apps/wallet/docs/adr/0005-plan-destination-and-planning-views.md) §5 froze the Plan **Budget view**: a per-category spending limit (sliders) + a monthly **savings target**, over an editable opt-in subset of categories (untracked spend pools into an **Other** residual), with a plain-arithmetic "Your month" readout. Building it against the current model surfaces a gap:

- **[ADR-0025](./0025-budget-period-centric-and-category-targeted.md)** stores budgets as one document **per category** per period, and carries **no savings target**.
- The **savings target** (ADR-0007's "target savings" lever) has **no persistence in code at all** — there is no `TargetSavings` anywhere in the Money service. It was slated as a `TargetSavingsSet` event on `AccountingPeriod` (PLAN §3.7), never built.

So the single surface the Budget view edits (this period's limits + target) maps to *N per-category documents that don't exist yet* + *a target that has no home*. The user's call (2026-07-10): **keep one target-budget record per (user, period)** — the savings target and the category limits live together, one record per period. No template layer.

Forces at play:

- The Budget view edits a period's **whole** budget at once (all sliders + the target on one screen), and it is the **single editor** of that state. ADR-0025's per-category-document granularity was chosen for per-category concurrency safety (mirroring the wishlist, ADR-0022) — but with one screen writing the whole set at solo scale, that granularity buys nothing and forces the view to fan a save into N calls. One record per period matches the editing unit.
- The savings target is **one number per period** — a natural field on a per-period record, not its own store or a lifecycle event whose history nobody folds (same reasoning ADR-0025 used to move the target *out* of the event store in the first place).
- **Actuals stay event-sourced and per-category.** `BudgetActuals` (ADR-0025) is keyed `(period, CategoryId)` and derived from flows; it is independent of how *targets* are stored. Consolidating targets does not touch it — `remaining` is still `limit − spent`, zipped at read time.
- ADR-0025's `Budget` document + endpoints are **not yet built** (no budget code exists), so superseding its storage shape pre-implementation is zero-cost — exactly as ADR-0025 itself superseded ADR-0006's aggregate pre-implementation.

## Decision

### `PeriodBudget` — one document per (owner, period)

```
PeriodBudget {
  Id:             Guid,                              // deterministic owner:year:month (upsert-idempotent)
  OwnerId:        string,                             // JWT sub (ADR-0004)
  Year, Month:    int,                               // the configurable period (ADR-0013)
  SavingsTarget:  CurrencyAmount?,                    // display currency; null = no target set
  CategoryLimits: Dictionary<Guid, CurrencyAmount>,   // CategoryId → limit, display currency
  TrackedCategories: Guid[],                          // opt-in subset scored against limits (ADR-0005 §5)
  UpdatedAt:      DateTimeOffset,
}
```

Keyed per **(owner, period)** — one document. A category with a limit but off `TrackedCategories` is not scored; its spend pools into the **Other** residual (no limit) in the Budget stats, per ADR-0005 §5. No category *creation* here (ADR-0005 §5 — that is the ADR-0024/0033 categories surface); the view only picks from existing categories.

### Actuals — `BudgetActuals` projection (unchanged from ADR-0025)

The `BudgetActuals` projection over `FlowRecorded` / `FlowReverted` lines — per-line grouping by `CategoryId`, signed sum, event-time FX to display currency — is **retained verbatim** from ADR-0025 §"Actuals aggregation". Only the *target* storage changed; the actuals side is untouched.

### Remaining & the "Your month" readout (read-time)

- Per category: `remaining = limit − spent`, computed at read time by zipping `PeriodBudget.CategoryLimits` with `BudgetActuals` for the period. Not stored.
- The Budget view's **"Your month"** readout is **plain arithmetic on the levers** — `expected income − Σ limits − SavingsTarget = free` (ADR-0005 §5), deliberately **not** `MonthProjection` (ADR-0007), so the view ships before that does.

### Savings target lives here (amends ADR-0007)

The monthly savings target is `PeriodBudget.SavingsTarget`. Home's on-track strip (projected vs target, ADR-0007) reads it from this record; variance is computed, not stored.

### Endpoints

- `GET /api/money/budgets?year=&month=` → the period's `PeriodBudget` (or an empty default: no target, no limits).
- `PUT /api/money/budgets?year=&month=` → upsert the whole period record (limits + target + tracked set). Idempotent on the deterministic id.
- Granular convenience writes MAY be added (`PUT …/savings-target`, `PUT …/limits/{categoryId}`) but the whole-record upsert is the contract the single-editor view needs.

### "Copy last period" (ADR-0025 stands)

The re-set-every-period cost is still handled client-side: the Wallet reads the prior period's `PeriodBudget` and `PUT`s it onto the new period. No recurring budget-template concept in v1.

### Period control on the Budget view (relaxes Wallet ADR-0005 §2)

Because the record is per-period, the Budget **view** carries a light period control (defaulting to the active period). Plan's List and Board views remain period-agnostic per ADR-0005 §2; only Budget selects a period.

## Consequences

Positive:

- One record is exactly the Budget view's editing unit — one load, one save, no N-call fan-out; matches how the surface is used.
- The savings target finally has a home, colocated with the limits it is weighed against, without a lifecycle event whose history nobody reads.
- `BudgetActuals` and every advisory/no-enforcement/no-rollover/canvas property of ADR-0025 are preserved — this is a target-storage change only.
- Pre-implementation supersede: zero refactor cost (no budget code exists).

Negative:

- A whole-record upsert is load-modify-store over the period's budget; two devices editing the same period's budget concurrently are last-write-wins on the record (not per-category). Acceptable at solo scale with a single editing surface; ADR-0025's per-category concurrency safety is traded away deliberately.
- Supersedes a frozen ADR's storage shape and amends ADR-0007's target home — requires cross-reference updates (documentation-only, pre-implementation).

Neutral:

- Money keeps four non-event-sourced document stores (UserPreferences, FX rates, Wishlist, Budget); the Budget store is now one-per-period instead of one-per-category-per-period.
- The Budget view gaining a period control is a small, explicit relaxation of ADR-0005 §2, scoped to that view only.

## Alternatives Considered

1. **Keep ADR-0025's per-(owner, period, CategoryId) documents + add a separate savings-target store.** Rejected per the user's call: the Budget view edits the whole period budget as one unit, so N per-category documents force a fan-out save and split the target from the limits it is judged against. One record per period matches the editing unit.
2. **A per-owner template document that seeds per-period instances ("templates set here").** Rejected: adds a template↔instance materialization layer and a seeding rule for every period, for a solo planner who re-sets rarely; ADR-0025's client-side "copy last period" already covers the re-set cost without new server machinery.
3. **Persist the savings target as a `TargetSavingsSet` event on `AccountingPeriod` (PLAN §3.7).** Rejected: the target is user-authored current-state whose history is not folded — the same reasoning ADR-0025 used to move budget targets out of the event store. A document field is the honest home; the close flow (ADR-0021) reads it, it need not be an event.
4. **Store `remaining` on the record.** Rejected (ADR-0025 Alt. 2 stands): `remaining = limit − spent`, and `spent` is a live projection over flows; storing it duplicates derivable state and goes stale.
5. **Give every Plan view a period switcher (drop §2 wholesale).** Rejected: List (definitions library) and Board (forward horizon) are genuinely period-agnostic; only Budget is per-period. The relaxation is scoped to Budget alone.

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.

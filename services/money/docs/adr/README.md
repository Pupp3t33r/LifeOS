# Money Service — Architecture Decision Records

This folder holds all architecture decisions specific to the Money service. Each ADR is a single markdown file following the [Nygard format](https://adr.github.io). Once an ADR is marked **Accepted**, its body is frozen — supersede via a new ADR, never edit.

See [`template.md`](./template.md) to start a new ADR.

## Accepted

| # | Title | Date |
|---|---|---|
| [0001](./0001-rest-contract-approach.md) | REST contract approach | 2026-06-14 |
| [0002](./0002-event-versioning-strategy.md) | Event versioning strategy | 2026-06-14 |
| [0003](./0003-idempotency-via-client-assigned-uuids.md) | Idempotency via client-assigned UUIDs | 2026-06-14 |
| [0004](./0004-zero-trust-jwt-validation.md) | Zero-trust JWT validation | 2026-06-14 |
| [0005](./0005-aggregate-boundaries.md) | Aggregate boundaries | 2026-06-14 |
| [0006](./0006-budget-aggregate.md) | Budget aggregate (light monthly category targets) | 2026-06-15 |
| [0007](./0007-monthly-review-and-projection.md) | MonthlyReview aggregate, Month projection, month-close flow | 2026-06-15 |
| [0008](./0008-multi-currency-and-fx.md) | Multi-currency CurrencyAmount value object and FX rate service (supersedes part of 0005) | 2026-06-15 |
| [0009](./0009-savings-accounts-and-month-close.md) | Savings accounts as the only account type | 2026-06-15 |
| [0010](./0010-asset-aggregate.md) | Asset aggregate (financial fields only) | 2026-06-15 |
| [0011](./0011-wolverine-http-conventions.md) | Wolverine.Http endpoint and handler conventions (supersedes part of 0001) | 2026-06-16 |
| [0012](./0012-production-schema-migration.md) | Production schema migration policy (no runtime auto-create) | 2026-06-16 |
| [0013](./0013-user-preferences-and-configurable-month.md) | UserPreferences document — configurable month start day and display currency (amends 0006, 0007) | 2026-06-24 |
| [0014](./0014-auth-session-lifetimes-and-passkeys.md) | Authentication UX — session lifetimes, passkeys, biometric app-lock (relates to 0004) | 2026-06-25 |
| [0015](./0015-fx-rate-sourcing-and-client-cache.md) | FX rate sourcing — Belarusbank card rates, plain BackgroundService, client rate cache (supersedes part of 0008, amends 0013) | 2026-06-26 |
| [0016](./0016-accounting-period-flow-ledger.md) | AccountingPeriod aggregate — per-month flow ledger for actuals (renames MonthlyReview, supersedes part of 0005, amends 0009) | 2026-06-26 |
| [0017](./0017-recurring-payment-rules-and-schedules.md) | RecurringPayment — recurrence-rule hierarchy, two schedule modes, period-tracked occurrences (supersedes InstallmentPlan from 0005, refines 0016) | 2026-06-26 |
| [0018](./0018-planned-purchases-on-accounting-period.md) | Planned purchases on AccountingPeriod — period-centric planning (supersedes PurchaseOrder from 0005, amends 0016/0010) | 2026-06-27 |
| [0019](./0019-universal-line-items.md) | Universal line-items for spending entries and estimates (amends 0016/0017) | 2026-06-27 |
| [0020](./0020-recurring-live-carry-make-up-defer.md) | Recurring Live carry-make-up defer (amends 0017) | 2026-06-27 |
| [0021](./0021-close-flow-multi-account-allocation-and-dispositions.md) | Close flow — multi-account allocation and item dispositions (amends 0007/0009) | 2026-06-27 |
| [0022](./0022-wishlist-items-packages-and-derived-status.md) | Wishlist items, packages, and derived status (supersedes WishlistItem from 0005) | 2026-06-27 |
| [0023](./0023-active-month-model.md) | Active-month model and period write permissions (refines 0007/0016) | 2026-06-27 |
| [0024](./0024-category-model.md) | Category model — managed system + user categories (supersedes dual-track tags, amends 0019/0006) | 2026-06-28 |
| [0025](./0025-budget-period-centric-and-category-targeted.md) | Budget — period-centric, category-targeted document (supersedes 0006 aggregate, amends 0006) | 2026-06-28 |
| [0026](./0026-actuals-honesty-and-savings-movements.md) | Actuals honesty & savings movements — drop override → `UnaccountedFlowRecorded`; names `SavingsMovementRecorded` (amends 0007/0021, resolves 0021 deferred sub-questions) | 2026-06-28 |
| [0027](./0027-early-payment-of-future-period-occurrence.md) | Early payment of a future-period occurrence — 2-event model (amends 0016/0017/0023) | 2026-06-28 |

## Superseded

| # | Title | Superseded by | Notes |
|---|---|---|---|
| 0005 §Multi-currency | Per-account `Dictionary<string, decimal>` balances; FX out of scope for v1 | [0008](./0008-multi-currency-and-fx.md) | Only the Multi-currency subsection is superseded. The rest of ADR-0005 stands. |
| 0001 §endpoint mechanism | Minimal APIs as the endpoint framework | [0011](./0011-wolverine-http-conventions.md) | Only the endpoint mechanism is superseded. ADR-0001's code-first OpenAPI decision stands. |
| 0007 §period-keying | `(Year, Month)` means a calendar month | [0013](./0013-user-preferences-and-configurable-month.md) | `(Year, Month)` now means the user's configured period (start day from UserPreferences). Key shape unchanged; `MonthStartDay = 1` degenerates to calendar months. The rest of ADR-0007 stands. |
| 0006 §period-keying | `(Year, Month)` means a calendar month | [0013](./0013-user-preferences-and-configurable-month.md) | Same generalization as 0007 for the `budget/{Owner}/{Year}/{Month}/...` key. The rest of ADR-0006 stands. |
| 0008 §FX-rate-service, §rate-by-context | Frankfurter-only rates via a Quartz daily cron | [0015](./0015-fx-rate-sourcing-and-client-cache.md) | Belarusbank card SELL rates (primary) + Frankfurter (fallback) via a plain hourly `BackgroundService`; client rate cache; server-authoritative actuals. The `CurrencyAmount` value object and single-currency-per-account decisions of ADR-0008 stand. |
| 0005 §transaction-model | `TransactionRecorded` on the Account stream; idempotency invariant on Account | [0016](./0016-accounting-period-flow-ledger.md) | Everyday flow actuals move to the per-period AccountingPeriod stream with the idempotency invariant relocated there. Account streams keep transactions for savings movements only. The aggregate taxonomy, tenancy, and inter-aggregate-consistency parts of ADR-0005 stand. |
| 0007 §MonthlyReview-aggregate | `MonthlyReview` aggregate holding period lifecycle only | [0016](./0016-accounting-period-flow-ledger.md) | Renamed **AccountingPeriod** and expanded to also hold `FlowRecorded`/`FlowReverted` flow entries. ADR-0007's `MonthProjection` and month-close flow stand; the projection's actuals input now comes from AccountingPeriod flow events. |
| 0005 §InstallmentPlan; RecurringPayment "tracks transaction IDs" | Separate `InstallmentPlan` aggregate; recurring tracks the transactions it produced | [0017](./0017-recurring-payment-rules-and-schedules.md) | Installments collapse into `RecurringPayment` (two schedule modes; no `installment/{…}` stream). Occurrences are tracked via back-references on AccountingPeriod `FlowRecorded` entries, not on the recurring aggregate. |
| 0016 §confirm-writes-LineConfirmed | Confirming a recurring line also appends `LineConfirmed` to the recurring stream | [0017](./0017-recurring-payment-rules-and-schedules.md) | Confirmation writes **only** `FlowRecorded` (with a `{recurringId, occurrenceRef}` back-reference) to AccountingPeriod; the recurring aggregate stores no per-occurrence state. |
| 0005 §PurchaseOrder-aggregate | `PurchaseOrder` aggregate (stream `purchase-order/{id}`, lifecycle Planned→Ordered→Received) | [0018](./0018-planned-purchases-on-accounting-period.md) | Planned purchases move to AccountingPeriod as events (`PlannedPurchaseAdded/Cancelled/Edited`); the PO is not built in v1. Fulfillment/asset tracking goes through the Asset aggregate directly (amends 0010). The aggregate taxonomy, tenancy, and inter-aggregate-consistency parts of ADR-0005 stand. |
| 0005 §WishlistItem | `WishlistItem` as an event-sourced aggregate on `wishlist/{id}` | [0022](./0022-wishlist-items-packages-and-derived-status.md) | Re-modeled as non-event-sourced documents (one per item + one per package) with a derived `WishlistItemStatus` projection. |
| 0010 §tracked-path | PO advances to Received → `AssetTracked` | [0018](./0018-planned-purchases-on-accounting-period.md) | A paid planned entry marked received creates an Asset directly (no PO intermediary). The pre-existing-import path and the Asset's financial-fields-only model stand; the Asset's full shape is deferred to Phase 3. |
| 0016 §FlowRecorded-amount | `FlowRecorded` carries a single `CurrencyAmount` + entry-level `tags` | [0019](./0019-universal-line-items.md) | `FlowRecorded` carries `list<Line>` (1..N); entry-level `tags` removed in favor of per-line `Category`. |
| 0017 §estimate-amount | Live estimate and Materialized `ScheduleLine.ExpectedAmount` are single `CurrencyAmount` | [0019](./0019-universal-line-items.md) | Both become `list<Line>`. Varying sums per month remain a Materialized property. |
| 0017 §Live-defer | Live occurrence defer = skip (or series cancel) | [0020](./0020-recurring-live-carry-make-up-defer.md) | Adds carry-make-up (skip + a disconnected `PlannedPurchaseAdded` next period with an `Origin` soft-ref) for arrears-creating recurring. |
| 0007 §close-flow | Close deposits/withdraws the whole surplus/deficit to one designated account | [0021](./0021-close-flow-multi-account-allocation-and-dispositions.md) | Surplus/deficit allocated across one or more savings accounts (split); unpaid-item dispositions added to the close transaction. `ClosingFxRates`, the `override ?? projected` final number, and lock semantics stand. |
| 0009 §close-account | Close movement lands in one designated savings account | [0021](./0021-close-flow-multi-account-allocation-and-dispositions.md) | Multiple savings accounts (split allocation); deficit is the mirror (user-chosen withdrawal accounts). The savings-only account type and transaction-derived balance stand. |
| 0021 §next-period-opening | (open question) must the next period be open, or does close open it? | [0023](./0023-active-month-model.md) | Periods accept planning on demand (future = planning-only); no open ceremony. Carry-at-close writes to the next period directly. |
| 0007/0016 §active-month | (implicit) one writable period at a time | [0023](./0023-active-month-model.md) | Multiple periods may be open; "one open period" is a UI default + close nudge, not a write invariant. Future periods are planning-only; actuals route by date (ADR-0016). |
| Dual-track tag stance (PLAN §9 + both AGENTS) | Categorization is dual-track `domain`/`tag`; no fixed category list | [0024](./0024-category-model.md) | Replaced by a **managed category model** (system Books/Board Games/Video Games + user categories). Tags are removed entirely; budgets target a `CategoryId`. |
| 0019 §Line.Category-union | `Line.Category: ExternalReference \| Tag` (single union) | [0024](./0024-category-model.md) | `Line` now carries `CategoryId: Guid?` (the single budgeting category) **and** a separate `ExternalRef: ExternalReference?` (a direct specific-object link, decoupled from categorization). Per-line `Line.WishlistItemId` unchanged. |
| 0006 §aggregate-choice | Budget as an event-sourced aggregate (`budget/{…}` stream) | [0025](./0025-budget-period-centric-and-category-targeted.md) | Budget becomes a **Marten document** keyed per (owner, period, CategoryId), consistent with the ADR-0013/0022 precedent for user-authored state. The light per-period / no-rollover / no-enforcement / display-currency-target parts of ADR-0006 stand. |
| 0006 §CategoryKey+sourcing | `CategoryKey` string (`domain:<svc>`/`tag:<text>`); actuals from `TransactionRecorded` + PO settlement | [0025](./0025-budget-period-centric-and-category-targeted.md) | Budgets target a **`CategoryId`** (ADR-0024); actuals are sourced from `FlowRecorded` lines grouped by per-line `CategoryId` (ADR-0016/0019), via a `BudgetActuals` projection. |
| 0007 §ActualSavingsOverride | `ActualSavingsOverride` field + `ActualSavingsOverridden` event; close formula `final = override ?? projectedSavings` | [0026](./0026-actuals-honesty-and-savings-movements.md) | Removed. The honesty valve becomes an `UnaccountedFlowRecorded` flow entry (the gap); **actual = Σ flows** always. Close allocates Σ flows across accounts; `Σ allocations = actual`. `TargetSavings`, `MonthClosed`, `ClosingFxRates`, and the lock ceremony stand. |
| 0021 §override-vs-allocations (was deferred) | Does the sum of allocations fold the override? | [0026](./0026-actuals-honesty-and-savings-movements.md) | **Resolved by elimination** — there is no override. `Σ allocations = actual = Σ flows`. |
| 0021 §dipping (was deferred) | Can a specific purchase draw from savings mid-month? | [0026](./0026-actuals-honesty-and-savings-movements.md) | **Resolved: close-time aggregate only.** A purchase exceeding income produces a period deficit; the close flow withdraws it from chosen account(s) (ADR-0021). No mid-month per-purchase withdrawals in v1 (deferred enhancement). |
| 0005/0009 §TransactionRecorded-on-Account | Generic `TransactionRecorded` event on the Account stream | [0026](./0026-actuals-honesty-and-savings-movements.md) | Superseded by **`SavingsMovementRecorded`** (signed amount, `Source: manual\|close`, reserved `TransferId`). Accounts remain balance-bearing single-currency aggregates; everyday flows never post to them (ADR-0016). |
| 0016 §period-events | `AccountingPeriod` carries lifecycle + flow + planned-purchase events | [0027](./0027-early-payment-of-future-period-occurrence.md) | Gains `OccurrencePaidInAdvance` / `OccurrencePaidInAdvanceRetracted` — status-reference markers (not actuals) for early-paid occurrences. |
| 0017 §occurrence-tracking | Occurrence status derived purely by within-period join; idempotency within one period | [0027](./0027-early-payment-of-future-period-occurrence.md) | Early-paid occurrences get a **local marker** on the occurrence's own period (a bounded, partial reversal of derive-by-join); early-pay idempotency is **stream-enforced** via Marten concurrency on the occurrence's period (replaces the within-period-only check for the cross-period case). Normal confirms unchanged. |
| 0023 §future-period-writes | Future periods accept planning operations only | [0027](./0027-early-payment-of-future-period-occurrence.md) | Named exception: an `OccurrencePaidInAdvance` status marker may be written to a future period **atomically with the paying actual** (same door ADR-0020 opened). Future periods still reject actuals (`FlowRecorded`) and close. |

## Deferred decisions

The following decisions have been identified but **intentionally deferred** until they can be grounded in real implementation work. Each will become an ADR when its forcing function arrives.

| Decision | Deferred until |
|---|---|
| CloudEvents envelope for Kafka events | The first Money event is published to Kafka |
| Wolverine outbox conventions (topic naming, partition keys) | The first cross-domain event is wired |
| Projection strategy (inline vs async, snapshots, rebuild) | The first projection lands (MonthProjection per ADR-0007 is the forcing function) |
| Transfer aggregate (first-class vs paired transactions) | Real-world transfer volume justifies a dedicated aggregate; for v1 paired transactions with `TransferId` suffice (ADR-0009) |
| Skip-periods (catch-up UX when months behind) | Wallet close-flow UX implementation (ADR-0023). |
| Asset aggregate shape (bundle→Asset granularity, `AssetTracked` event, Asset fields) | Phase 3 Asset implementation (amends ADR-0010; the paid-entry→Asset path is fixed in ADR-0018, the shape is not). |
| `ExternalReference` snapshot caching (short cached descriptor — title/thumbnail — for a linked domain object, so the UI need not query the owning service) | Phase 2 — the first domain service comes online and `ExternalRef` is first populated (in Phase 1 no domain service exists, so no `ExternalRef` is populated and there is nothing to snapshot). Mechanism: client-supplied snapshot at link time (Money never calls other services); sub-decision inline-on-`ExternalReference` vs separate `ExternalObjectInfo` doc. |

## Numbering

ADRs are numbered in acceptance order (the order in which they were marked Accepted). Numbers are **monotonic and never reused**. Per the per-service ADR convention, Money's numbering is independent of other services — each service's ADR folder starts at 0001.

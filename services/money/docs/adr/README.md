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

## Deferred decisions

The following decisions have been identified but **intentionally deferred** until they can be grounded in real implementation work. Each will become an ADR when its forcing function arrives.

| Decision | Deferred until |
|---|---|
| CloudEvents envelope for Kafka events | The first Money event is published to Kafka |
| Wolverine outbox conventions (topic naming, partition keys) | The first cross-domain event is wired |
| Projection strategy (inline vs async, snapshots, rebuild) | The first projection lands (MonthProjection per ADR-0007 is the forcing function) |
| Tag storage (Marten documents vs side table vs projection-only) | The first tag-consuming feature is implemented (budgets by tag per ADR-0006, transaction tag filtering) |
| Transfer aggregate (first-class vs paired transactions) | Real-world transfer volume justifies a dedicated aggregate; for v1 paired transactions with `TransferId` suffice (ADR-0009) |

## Numbering

ADRs are numbered in acceptance order (the order in which they were marked Accepted). Numbers are **monotonic and never reused**. Per the per-service ADR convention, Money's numbering is independent of other services — each service's ADR folder starts at 0001.

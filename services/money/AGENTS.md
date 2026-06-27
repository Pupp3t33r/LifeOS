# Money Service — Agent Context

> **Parent:** [Root AGENTS.md](../../AGENTS.md)  
> **Depth:** Very Deep  
> **Stack:** .NET 10, PostgreSQL + Marten, Wolverine  
> **Roadmap:** [PLAN.md](./PLAN.md) (current state, refactors, feature build order)

## Service Identity

Money owns all financial state. No other service stores cost, payment schedules, or wishlist data.

**Owned domains:**
- Savings accounts (checking/credit/cash are out of scope — see ADR-0009)
- AccountingPeriod — per-month stream holding lifecycle + flow ledger (actuals) + planned purchases (ADR-0016/0018/0019); renamed from MonthlyReview
- Flow actuals (`FlowRecorded` / `FlowReverted`, line-itemed — ADR-0019)
- Recurring payments (Live rule + Materialized list; installments/debt are Materialized — ADR-0017)
- Planned purchases (events on AccountingPeriod, line-itemed — ADR-0018/0019)
- Wishlist (desired items + packages, non-event-sourced documents with derived status — ADR-0022)
- Budgets (light per-period category targets — ADR-0006; per-line categorization ADR-0019)
- UserPreferences (non-event-sourced document — ADR-0013)
- Assets (owned items, financial fields only — ADR-0010; Phase 3, ingestion via paid-entry → Asset per ADR-0018)
- FX rates (Belarusbank card SELL rates primary + Frankfurter fallback — ADR-0015)
- Event store (Marten streams) + non-event-sourced documents (UserPreferences, FX rates, Wishlist items/packages)

## Tech Stack

| Component | Choice |
|---|---|
| Event Store | Marten on PostgreSQL |
| Messaging | Wolverine (Kafka transport, outbox with Marten) |
| Validation | FluentValidation |
| Logging | Serilog (JSON output) |
| Cron | Quartz.NET (available; the FX sync uses a plain `BackgroundService` per ADR-0015) |
| FX rates | Belarusbank card SELL rates (primary) + Frankfurter (fallback) — ADR-0015 |

## Decisions

Architecture decisions are recorded as ADRs in [`docs/adr/`](./docs/adr/). The full index lives in [`docs/adr/README.md`](./docs/adr/README.md).

| # | Decision |
|---|---|
| [0001](./docs/adr/0001-rest-contract-approach.md) | Code-first REST with Minimal APIs and vertical-slice folders |
| [0002](./docs/adr/0002-event-versioning-strategy.md) | Event versioning: dev mode drops freely; post-release uses new event types only |
| [0003](./docs/adr/0003-idempotency-via-client-assigned-uuids.md) | Idempotency via client-assigned UUIDs as primary keys |
| [0004](./docs/adr/0004-zero-trust-jwt-validation.md) | Zero-trust JWT validation (Money re-validates signatures) |
| [0005](./docs/adr/0005-aggregate-boundaries.md) | Aggregate boundaries (partially superseded by 0008) |
| [0006](./docs/adr/0006-budget-aggregate.md) | Budget aggregate — light monthly category targets, no envelopes, no rollover |
| [0007](./docs/adr/0007-monthly-review-and-projection.md) | MonthlyReview aggregate + Month projection read-model + month-close flow |
| [0008](./docs/adr/0008-multi-currency-and-fx.md) | Multi-currency `CurrencyAmount` value object, single-currency-per-account, Frankfurter FX rate service |
| [0009](./docs/adr/0009-savings-accounts-and-month-close.md) | Savings accounts as the only account type |
| [0010](./docs/adr/0010-asset-aggregate.md) | Asset aggregate (financial fields only) — Phase 3 implementation, data model locked now |
| [0011](./docs/adr/0011-wolverine-http-conventions.md) | Wolverine.Http endpoint/handler conventions (supersedes the Minimal APIs mechanism of 0001) |
| [0012](./docs/adr/0012-production-schema-migration.md) | Production schema migration policy — no runtime auto-create; migrate via pre-deploy step |
| [0013](./docs/adr/0013-user-preferences-and-configurable-month.md) | UserPreferences document — configurable month start day and display currency (amends 0006, 0007) |
| [0014](./docs/adr/0014-auth-session-lifetimes-and-passkeys.md) | Auth UX — session lifetimes, passkeys, biometric app-lock (relates to 0004) |
| [0015](./docs/adr/0015-fx-rate-sourcing-and-client-cache.md) | FX rate sourcing — Belarusbank card rates + plain BackgroundService + client cache (supersedes part of 0008, amends 0013) |
| [0016](./docs/adr/0016-accounting-period-flow-ledger.md) | AccountingPeriod aggregate — per-month flow ledger for actuals (renames MonthlyReview, supersedes part of 0005, amends 0009) |
| [0017](./docs/adr/0017-recurring-payment-rules-and-schedules.md) | RecurringPayment — recurrence-rule hierarchy, two schedule modes, period-tracked occurrences (collapses InstallmentPlan) |
| [0018](./docs/adr/0018-planned-purchases-on-accounting-period.md) | Planned purchases on AccountingPeriod — period-centric planning (supersedes PurchaseOrder from 0005, amends 0016/0010) |
| [0019](./docs/adr/0019-universal-line-items.md) | Universal line-items for spending entries and estimates (amends 0016/0017) |
| [0020](./docs/adr/0020-recurring-live-carry-make-up-defer.md) | Recurring Live carry-make-up defer (amends 0017) |
| [0021](./docs/adr/0021-close-flow-multi-account-allocation-and-dispositions.md) | Close flow — multi-account allocation and item dispositions (amends 0007/0009) |
| [0022](./docs/adr/0022-wishlist-items-packages-and-derived-status.md) | Wishlist items, packages, and derived status (supersedes WishlistItem from 0005) |
| [0023](./docs/adr/0023-active-month-model.md) | Active-month model and period write permissions (refines 0007/0016) |

## Service-Specific Standards

### Event Sourcing

- **Marten for aggregates and event streams only.** All state changes are events.
- **Aggregates live in `Domain/`**. Example: `Domain/Account.cs`, `Domain/RecurringPayment.cs`, `Domain/AccountingPeriod.cs` (renamed from MonthlyReview — ADR-0016).
- **Projections live in `Projections/`**. Example: `Projections/MonthProjection.cs`, `Projections/WishlistItemStatus.cs` (ADR-0022).
- **Non-event-sourced documents** (UserPreferences, FX rates, Wishlist items/packages) live alongside as Marten documents, not aggregates — see ADR-0013/0015/0022.
- **Do not expose raw event streams.** Always query projections for read models.

### CurrencyAmount value object (ADR-0008)

All monetary amounts are `CurrencyAmount(decimal Amount, string Currency)`, not bare `decimal`. This applies to events, projections, DTOs, and aggregates. The Wallet app renders multi-currency values as "original + converted inline" (e.g., "€80 (~$86)") in the user's chosen display currency.

### Cross-service references

Cross-domain references use the canonical pair `ExternalReference(string ServiceType, Guid ExternalId)` wherever Money points at things owned by other services (Books, Board Games, etc.). Money never stores the descriptive metadata — only the pointer.

### Wolverine Outbox

- **All cross-domain events from Money must go through Wolverine's outbox.**
- Outbox uses shared PostgreSQL transaction with Marten — events are atomically committed with the aggregate change.
- Example: `Publish(new FlowRecorded(...))` inside a Marten session handler.

### Feature Organization

```
Features/
  Transactions/
    RecordExpense.cs              (endpoint + handler)
    RecordExpenseRequest.cs       (request record)
    RecordExpenseResponse.cs      (response record)
    RecordExpenseValidator.cs
  Recurring/
    CreateSchedule.cs
    CreateScheduleRequest.cs
    CreateScheduleResponse.cs
    CreateScheduleValidator.cs
  AccountingPeriod/
    ClosePeriod.cs
    AddPlannedPurchase.cs
    RecordFlow.cs
    SetTargetSavings.cs
    ...
```

### No EF Core

- **Do not use EF Core in Money.** Marten is the only data access tool.
- Use Marten queries (`session.Query<T>()`) for read models.

### Categorization (dual-track, per-line — ADR-0006/0019)

Categorization is applied **per `Line`** on `FlowRecorded` and `PlannedPurchaseAdded` entries (one entry may carry lines in several categories). Each line's `Category` is exactly one of two tracks:

- **Domain categorization (implicit):** an `ExternalReference(serviceType, externalId)` on the line. Categories are derived from the linked service (`books`, `board-games`, etc.).
- **Tag categorization (explicit):** a free-text `Tag` on the line. Tags are categorization data, not financial state — storage mechanism is a deferred decision (see `docs/adr/README.md`).

Budgets target either track via `CategoryKey`: `domain:<serviceType>` or `tag:<tagtext>`. The domains-vs-tags-vs-special-meaning refinement is deferred (see ADR README).

## Events Owned

| Event | Consumed By | Status |
|---|---|---|
| `FlowRecorded` / `FlowReverted` (ADR-0016/0019) | Planner (future), Scheduler | Draft |
| `PlannedPurchaseAdded` / `Cancelled` / `Edited` (ADR-0018) | — | Draft |
| `MonthClosed` (ADR-0007/0021) | — | Draft |
| `AssetTracked` (Phase 3; from a paid entry marked received — ADR-0018) | Books / Board Games | Deferred (Phase 3) |
| `AssetSold` | Books / Board Games (mark item no longer owned) | Deferred (Phase 3) |

**Note:** The old `TransactionRecorded` (on Account) is superseded by `FlowRecorded` on AccountingPeriod (ADR-0016) for everyday actuals; Account streams keep savings-movement events only. `PurchaseOrderCreated/Received` are dropped (PurchaseOrder aggregate removed — ADR-0018). Wishlist changes are non-event-sourced (ADR-0022). Event schemas are designed during feature implementation; this table is a placeholder until each lands.

## Anti-Patterns

- ❌ **Do not use EF Core.** Marten only.
- ❌ **Do not expose raw event streams.** Use projections.
- ❌ **Do not emit cross-domain events without Wolverine outbox.** Always atomic.
- ❌ **Do not put business logic in API endpoints.** Handlers only.
- ❌ **Do not create generic repositories.** Use Marten `IDocumentSession` directly.
- ❌ **Do not store item descriptive metadata (title, ISBN, BGG ID, cover).** Other services own that; Money holds only `ExternalReference` pointers.
- ❌ **Do not add account types beyond savings.** All accounts are savings accounts (ADR-0009).
- ❌ **Do not store bare `decimal` monetary amounts.** Use `CurrencyAmount(decimal, string)` (ADR-0008); spending entries carry `list<Line>` (ADR-0019).
- ❌ **Do not model planned purchases as a separate aggregate (PurchaseOrder).** They are events on AccountingPeriod (ADR-0018).
- ❌ **Do not store wishlist item status on the item document.** It is a derived projection (ADR-0022).
- ❌ **Do not record actuals in or close a future period.** Future periods accept planning operations only; actuals route by date, close belongs to the active period (ADR-0023).

---

*Last updated: 2026-06-27*

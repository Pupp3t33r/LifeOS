# Money Service — Agent Context

> **Parent:** [Root AGENTS.md](../../AGENTS.md)  
> **Depth:** Very Deep  
> **Stack:** .NET 10, PostgreSQL + Marten, Wolverine  
> **Roadmap:** [PLAN.md](./PLAN.md) (current state, refactors, feature build order)

## Service Identity

Money owns all financial state. No other service stores cost, payment schedules, or wishlist data.

**Owned domains:**
- Savings accounts (checking/credit/cash are out of scope — see ADR-0009)
- Transactions (expenses, income, transfers)
- Recurring payments (infinite schedules)
- Installments (finite schedules with end dates)
- Wishlist (desired items with cost estimates, optionally linked to other domains via `{ serviceType, externalId }`)
- Purchase orders (planned buys; lifecycle: Planned → Ordered → Received)
- Budgets (light monthly category targets — see ADR-0006)
- Monthly reviews (target/projected/actual savings per month — see ADR-0007)
- Assets (owned items, financial fields only — see ADR-0010; Phase 3 implementation)
- FX rates (daily Frankfurter sync — see ADR-0008)
- Event store (Marten streams for all financial events)

## Tech Stack

| Component | Choice |
|---|---|
| Event Store | Marten on PostgreSQL |
| Messaging | Wolverine (Kafka transport, outbox with Marten) |
| Validation | FluentValidation |
| Logging | Serilog (JSON output) |
| Cron | Quartz.NET (used by the FX rate sync job; see ADR-0008) |
| FX rates | Frankfurter API (ECB-based, no API key) |

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

## Service-Specific Standards

### Event Sourcing

- **Marten for aggregates and event streams only.** All state changes are events.
- **Aggregates live in `Domain/`**. Example: `Domain/Account.cs`, `Domain/RecurringPayment.cs`, `Domain/MonthlyReview.cs`.
- **Projections live in `Projections/`**. Example: `Projections/TransactionRecord.cs`, `Projections/MonthProjection.cs`.
- **Do not expose raw event streams.** Always query projections for read models.

### CurrencyAmount value object (ADR-0008)

All monetary amounts are `CurrencyAmount(decimal Amount, string Currency)`, not bare `decimal`. This applies to events, projections, DTOs, and aggregates. The Wallet app renders multi-currency values as "original + converted inline" (e.g., "€80 (~$86)") in the user's chosen display currency.

### Cross-service references

Cross-domain references use the canonical pair `ExternalReference(string ServiceType, Guid ExternalId)` wherever Money points at things owned by other services (Books, Board Games, etc.). Money never stores the descriptive metadata — only the pointer.

### Wolverine Outbox

- **All cross-domain events from Money must go through Wolverine's outbox.**
- Outbox uses shared PostgreSQL transaction with Marten — events are atomically committed with the aggregate change.
- Example: `Publish(new TransactionRecorded(...))` inside a Marten session handler.

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
  MonthlyReview/
    CloseMonth.cs
    SetTargetSavings.cs
    ...
```

### No EF Core

- **Do not use EF Core in Money.** Marten is the only data access tool.
- Use Marten queries (`session.Query<T>()`) for read models.

### Categorization (dual-track)

A purchase or transaction is categorized by exactly one of two tracks (see ADR-0006 and `apps/wallet/PLAN.md`):

- **Domain categorization (implicit):** `serviceType + externalId` on the PurchaseOrder. Categories are derived from the linked service (`books`, `board-games`, etc.).
- **Tag categorization (explicit):** free-text tags applied to transactions. Tags are categorization data, not financial state — storage mechanism is a deferred decision (see `docs/adr/README.md`).

Budgets target either track via `CategoryKey`: `domain:<serviceType>` or `tag:<tagtext>`.

## Events Owned

| Event | Consumed By | Status |
|---|---|---|
| `TransactionRecorded` | Planner (future), Scheduler | Draft |
| `PurchaseOrderCreated` | — | Draft |
| `PurchaseOrderReceived` | — | Draft (Phase 3 will produce AssetTracked from this) |
| `WishlistItemAdded` | Planner (budget projection) | Draft |
| `MonthClosed` | — | Draft (per ADR-0007) |
| `AssetSold` | Books / Board Games (to mark item no longer owned) | Deferred (Phase 3) |

**Note:** Event schemas are designed during feature implementation. This table is a placeholder until each event lands.

## Anti-Patterns

- ❌ **Do not use EF Core.** Marten only.
- ❌ **Do not expose raw event streams.** Use projections.
- ❌ **Do not emit cross-domain events without Wolverine outbox.** Always atomic.
- ❌ **Do not put business logic in API endpoints.** Handlers only.
- ❌ **Do not create generic repositories.** Use Marten `IDocumentSession` directly.
- ❌ **Do not store item descriptive metadata (title, ISBN, BGG ID, cover).** Other services own that; Money holds only `ExternalReference` pointers.
- ❌ **Do not add account types beyond savings.** All accounts are savings accounts (ADR-0009).
- ❌ **Do not store bare `decimal` monetary amounts.** Use `CurrencyAmount(decimal, string)` (ADR-0008).

---

*Last updated: 2026-06-15*

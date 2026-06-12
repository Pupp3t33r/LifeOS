# Money Service — Agent Context

> **Parent:** [Root AGENTS.md](../../AGENTS.md)  
> **Depth:** Very Deep  
> **Stack:** .NET 10, PostgreSQL + Marten, Wolverine

## Service Identity

Money owns all financial state. No other service stores cost, payment schedules, or wishlist data.

**Owned domains:**
- Accounts (checking, savings, credit cards)
- Transactions (expenses, income, transfers)
- Recurring payments (schedules, predictions)
- Installments (tracking, amortization)
- Purchase orders (planned buys)
- Wishlist (desired items with cost estimates)
- Event store (Marten streams for all financial events)

## Tech Stack

| Component | Choice |
|---|---|
| Event Store | Marten on PostgreSQL |
| Messaging | Wolverine (Kafka transport, outbox with Marten) |
| Validation | FluentValidation |
| Logging | Serilog (JSON output) |
| Cron | Quartz.NET |

## Service-Specific Standards

### Event Sourcing

- **Marten for aggregates and event streams only.** All state changes are events.
- **Aggregates live in `Domain/`**. Example: `Domain/Account.cs`, `Domain/TransactionStream.cs`.
- **Projections live in `Projections/`**. Example: `Projections/AccountBalanceProjection.cs`.
- **Do not expose raw event streams.** Always query projections for read models.

### Wolverine Outbox

- **All cross-domain events from Money must go through Wolverine's outbox.**
- Outbox uses shared PostgreSQL transaction with Marten — events are atomically committed with the aggregate change.
- Example: `Publish(new TransactionRecorded(...))` inside a Marten session handler.

### Feature Organization

```
Features/
  Transactions/
    RecordExpense.cs              (endpoint + handler + request + response)
    RecordExpenseValidator.cs
  Recurring/
    CreateSchedule.cs
```

### No EF Core

- **Do not use EF Core in Money.** Marten is the only data access tool.
- Use Marten queries (`session.Query<T>()`) for read models.

## Events Owned

| Event | Consumed By | Status |
|---|---|---|
| `TransactionRecorded` | Planner (future), Scheduler | Draft |
| `PurchaseOrderCreated` | — | Draft |
| `WishlistItemAdded` | Planner (budget projection) | Draft |

**Note:** Event schemas are designed during feature implementation. This table is a placeholder.

## Anti-Patterns

- ❌ **Do not use EF Core.** Marten only.
- ❌ **Do not expose raw event streams.** Use projections.
- ❌ **Do not emit cross-domain events without Wolverine outbox.** Always atomic.
- ❌ **Do not put business logic in API endpoints.** Handlers only.
- ❌ **Do not create generic repositories.** Use Marten `IDocumentSession` directly.

---

*Last updated: 2026-05-25*

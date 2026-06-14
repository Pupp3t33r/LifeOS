# ADR-0005: Aggregate boundaries

## Status

Accepted

Date: 2026-06-14

## Context

The first Money domain feature is about to be implemented. The deferred-decisions list in the ADR README flags this as the forcing function for deciding aggregate boundaries. Every event shape, stream layout, idempotency mechanism, and projection depends on this decision, so it must be settled before any domain code is written.

Money is a personal finance application for a single primary user (with potential family members via `OwnerId` scoping). The owner's actual priorities are: tracking recurring obligations (rent, subscriptions, installments), projecting income and expenses, and deciding how to use spare money. Generic transaction recording is the *substrate* that enables those features, not the headline value. Money is event-sourced (Marten), so aggregate boundaries govern both consistency and read-path cost.

Forces at play:

- ADR-0003 mandates idempotency via client-assigned UUIDs enforced as an **aggregate invariant** — the dedup check must live inside an aggregate.
- Money is single-user in spirit. Concurrent writes to the same account are rare; single-stream contention is acceptable.
- Multi-currency is required from day one (balances are per currency code).
- Account longevity is high — an account may accumulate years of transactions. Stream size and rebuild cost matter over time but are not v1 blockers.
- The rich domain concepts (recurring payments, installments, purchase orders) have lifecycles independent of any single account and must not be coupled into the Account aggregate.

## Decision

Money uses an **account-centric stream model for transactions**, with the richer domain concepts as **separate aggregates** on their own streams. Transaction is **never an aggregate** — it is an event and a read-model row, nothing more.

### Aggregate taxonomy

| Aggregate | Stream key | Owns | Lifecycle |
|---|---|---|---|
| **Account** | `account/{AccountId}` | Per-currency balances, recorded transaction ID set (idempotency invariant), owner, name | Long-lived |
| **RecurringPayment** | `recurring/{RecurringPaymentId}` | Amount, currency, frequency, next-due date, direction (in/out), optional end date, status | Independent — pause, skip, edit, complete |
| **InstallmentPlan** *(future)* | `installment/{InstallmentPlanId}` | A fixed-term recurring with progress (paid N of M) | Ends when complete |
| **WishlistItem** *(future)* | `wishlist/{WishlistItemId}` | Desired good reference + estimated cost | Until converted or removed |
| **PurchaseOrder** *(future)* | `purchase-order/{PurchaseOrderId}` | Line items, payment schedule, delivery snapshot, linked transaction IDs | Until delivered/cancelled |

### Transaction model

`TransactionRecorded` is an **event on the Account stream**, not its own aggregate. The Account aggregate folds transactions into per-currency balances and tracks the set of recorded transaction IDs to enforce ADR-0003 idempotency atomically with the balance update.

A flat **`TransactionRecord` projection** (one document per `TransactionRecorded` event) provides transaction-level reads and is the source of truth for the ADR-0003 payload comparison on duplicate IDs (200 vs 409). The projection is updated inline with the event append.

### Inter-aggregate consistency

Two or more Money aggregates may be mutated in a **single Marten `IDocumentSession` transaction** — events appended to multiple streams commit atomically. This is used when a RecurringPayment fires: the handler appends `RecurringPaymentPaid` to the recurring stream *and* `TransactionRecorded` to the account stream in one transaction. No saga, no process manager, no outbox is required for intra-Money consistency (cross-service consistency still goes through the Wolverine outbox per the Money AGENTS.md, deferred until the first Kafka event).

### Multi-currency

Each `Account` holds `Balances` as a `Dictionary<string, decimal>` keyed by ISO 4217 currency code. `AccountOpened` does **not** declare a currency list — currency balances emerge from the first transaction in that code. Exchange-rate conversion and FX events are out of scope for v1; each currency balance is independent.

### Tenancy

Every aggregate carries an `OwnerId` populated from the JWT `sub` claim (ADR-0004). Queries scope by `OwnerId`. This is the full extent of multi-tenancy — one shared schema, filtered per user. No tenant-routing middleware, no per-tenant database isolation.

## Relationships and cross-service linkage

Relationships between Money aggregates and other Money aggregates, or between Money aggregates and entities in other services, live on the **richer aggregate**, never on `TransactionRecorded`. The transaction event stays a generic ledger primitive forever — it carries no good reference, no purchase-order reference, no recurring-payment reference. This keeps the most frequently emitted event stable.

Specifically:

- A **PurchaseOrder** (Phase 5) references its line items as `{ serviceType, externalId }` pairs pointing at goods in other services (Books, Board Games, etc.), and references the **transaction IDs** that settled it. The reverse link (transaction → purchase order) is not stored on the transaction.
- A **RecurringPayment** references the account it draws from and tracks the transaction IDs it produced when it fired.
- **Cross-service delivery dates**: the authoritative ship/delivery date lives in the good's service (it knows publisher/shipping reality). Money's PurchaseOrder holds a **denormalized snapshot** of the expected delivery date, updated via Kafka events (e.g., `inventory.boardgame.shipped`), purely so Money's own projections can reason about timing without a sync call. Money never queries another service.

The cross-service reference key is the pair `{ serviceType: string, externalId: Guid }` mandated by the root AGENTS.md. Money never stores the good's metadata — only the pointer. The Gateway composes Money data with the good's service data for frontend display.

## Consequences

Positive:

- ADR-0003 idempotency is a natural aggregate invariant: "have I already recorded this TransactionId?" is checked atomically with the balance update, in one stream.
- Balance is a pure fold of events — no cross-stream aggregation needed for the most common read.
- Recurring payments, installments, and purchase orders get the rich aggregate lifecycles they deserve without bloating the Account stream with unrelated state.
- `TransactionRecorded` is frozen forever as a generic primitive; future goods/purchase-order integration never mutates its shape.
- Single-stream optimistic concurrency (Marten's stream versioning) is sufficient for a single-user app.

Negative:

- Long-lived accounts grow large event streams. Mitigated post-1.0 by Marten snapshots; not a v1 concern.
- All transactions for one account serialize on the stream. Acceptable for personal finance volume; would be wrong for a high-throughput multi-tenant ledger.
- Cross-aggregate reads (e.g., "show me this month's activity across all recurring payments and the account") require a projection that consumes events from multiple streams.

Neutral:

- The flat `TransactionRecord` projection is mandatory from day one (needed for ADR-0003 payload comparison and for transaction-level reads). This is consistent with the Money AGENTS.md rule that raw event streams are never exposed — reads go through projections.

## Alternatives Considered

1. **Separate `Transaction` aggregate on its own stream.** Each `TransactionRecorded` lives on `transaction/{TransactionId}`. Balance becomes a projection aggregating across many transaction streams. Rejected: loses atomic balance updates, complicates the ADR-0003 idempotency story (no natural aggregate to hold the dedup invariant — needs a side table or extra read to distinguish 200 from 409), and forces a heavier projection for the most common read. Better suited to high-volume multi-tenant ledgers than to a personal finance app.
2. **One stream per currency per account.** Isolates each currency's balance to its own stream. Rejected: fragments account identity, complicates "what does this account hold?" reads, and offers no benefit since cross-currency contention is not a real concern for a single user.
3. **Put transactions, recurring payments, and installments all inside the Account aggregate.** Rejected: couples unrelated lifecycles (pausing a subscription should not require loading or contending with the account's transaction history), grows streams even faster, and violates the single-responsibility principle the rich domain concepts demand.

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.

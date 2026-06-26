# ADR-0016: AccountingPeriod aggregate — per-month flow ledger for actuals

## Status

Accepted

Date: 2026-06-26

**Supersedes:**
- The **transaction model** of [ADR-0005](./0005-aggregate-boundaries.md) — `TransactionRecorded` as an event on the **Account** stream, and the ADR-0003 idempotency invariant living on **Account** — *for everyday income/expense actuals*. Account streams retain transactions only for savings movements (see below).
- The **MonthlyReview aggregate** section of [ADR-0007](./0007-monthly-review-and-projection.md). `MonthlyReview` is renamed **AccountingPeriod** and expanded to also hold flow entries. ADR-0007's `MonthProjection` read-model and month-close flow stand, with the projection's *actuals* input now sourced from AccountingPeriod flow events.

**Amends:** [ADR-0009](./0009-savings-accounts-and-month-close.md) — account transactions are now **savings movements only**.

**Relocates:** the [ADR-0003](./0003-idempotency-via-client-assigned-uuids.md) idempotency invariant for flow actuals onto AccountingPeriod.

## Context

A contradiction surfaced when implementing recurring-payment confirmation. The built `RecordTransactionEndpoint` posts to `/accounts/{accountId}/transactions`: every transaction **belongs to an account**, must match its currency, carries the idempotency invariant on that account, and **moves its balance** (ADR-0005, ADR-0009). But:

- **ADR-0009 makes every account a savings account** and explicitly rejected a spending/checking account type.
- **ADR-0007's month-close** adds only the *net surplus* to a savings account at close.

So everyday spending has no consistent home. Posting a confirmed rent payment to a savings account **wrongly drains savings**, and then close adds the surplus on top — **double-counting**. Everyday spending must not touch a savings balance during the month, yet the transaction model requires every transaction to belong to an account, and the only accounts are savings.

The planner's real structure is two distinct ledgers:

- **Flow** — within-month income and expense actuals that refine projected savings. Not balance-bearing. Multi-currency by nature.
- **Stock** — savings account balances, which change only via deliberate movements (transfers) and the close-day surplus/deficit.

The active-month / period model (one writable open period that seals at close) maps one-to-one onto a **per-month stream**: a month's actuals *are* one stream, closing the month seals it, and the stream stays bounded. `MonthlyReview` (ADR-0007) is already a per-period aggregate, but it only holds review lifecycle — the flow actuals have no aggregate at all.

## Decision

### AccountingPeriod aggregate

Rename `MonthlyReview` to **`AccountingPeriod`** and expand it to be the single per-month stream holding **both** the period lifecycle **and** the flow ledger.

Stream key: `period/{OwnerId}/{Year}/{Month}` — one stream per user per period (period per ADR-0013; `MonthStartDay = 1` degenerates to calendar months). It carries the ADR-0007 lifecycle state (`TargetSavings`, `ActualSavingsOverride`, `Notes`, `Status`, `ClosedAt`, `ClosingFxRates`) plus the set of recorded flow-entry IDs (idempotency invariant).

### Events

Lifecycle (from ADR-0007, unchanged): `MonthOpened`, `TargetSavingsSet`, `ActualSavingsOverridden`, `MonthClosed`.

Flow (new):
- `FlowRecorded` — an income or expense actual. Carries a client-assigned `EntryId` (UUID, ADR-0003), `CurrencyAmount`, direction (in/out), actual date, description, tags (subject to the deferred tag-storage decision), and optional links (e.g. a recurring line id, a PurchaseOrder id).
- `FlowReverted` — an append-only compensating entry that reverses a prior `FlowRecorded` (the ledger is immutable; corrections never mutate or delete).

Once `MonthClosed`, the stream rejects all further events — lifecycle *and* flow (ADR-0007's lock semantics now also cover flow).

### Flow entries are not balance-bearing and are multi-currency

A `FlowRecorded` entry refines the month's projected-vs-actual savings; it never moves a savings-account balance. Because it is not balance-bearing, a single period stream may hold entries in **mixed currencies** (each its own `CurrencyAmount`), unlike an Account. `MonthProjection` aggregates them into the display currency.

### Idempotency relocates to AccountingPeriod

The ADR-0003 dedup invariant for flow actuals moves onto AccountingPeriod: the aggregate tracks recorded `EntryId`s and checks duplicates atomically with the append (200 on identical replay, 409 on conflicting payload) — the same mechanism ADR-0005 placed on Account, now on the period. Account streams keep their own idempotency for savings movements.

### Period assignment

A flow entry lands in the AccountingPeriod of its **actual date** (ADR-0013 period mapping; consistent with ADR-0008's "actuals use the transaction-date rate"). An entry confirmed late posts to the period its actual date falls in, not the period it was due.

### Accounts narrow to savings movements (amends ADR-0009)

Account streams retain transactions **only** for savings movements: opening balance, inter-account transfers (paired entries with `TransferId`, ADR-0009), and the close-day surplus/deficit deposit/withdrawal (ADR-0007). Accounts remain balance-bearing and single-currency; everyday spending/income never posts to them.

### Endpoints

- New period-scoped endpoint appends flow: `POST /months/{year}/{month}/transactions` → `FlowRecorded` on `period/{owner}/{year}/{month}`.
- The built `/accounts/{accountId}/transactions` narrows to savings movements.
- Confirming a recurring line appends `LineConfirmed` (recurring stream) **and** `FlowRecorded` (period stream) in **one Marten transaction** — the multi-stream append ADR-0005 already permits for intra-Money atomicity.

### MonthProjection and close flow

`MonthProjection` (ADR-0007) is unchanged in purpose. Its **actuals** input now comes from AccountingPeriod `FlowRecorded`/`FlowReverted` events instead of account-stream `TransactionRecord`. The month-close flow is unchanged: the close-day surplus/deficit still posts as a savings movement on the designated account's stream.

## Consequences

Positive:

- Resolves the contradiction: flow (period stream) and stock (account streams) are cleanly separated; everyday spending never drains savings, no double-count at close.
- One stream per month is the simplest mental model — everything about a month (plan, actuals, lifecycle) is in one place — and it is **bounded** (a month has limited entries), avoiding the ever-growing account-stream concern.
- The per-month stream matches the active-month / close model exactly: sealing the stream *is* closing the month.
- Idempotency is a natural invariant on the period aggregate.
- The flow ledger is multi-currency-tolerant for free — foreign spending sits with its own currency and the canvas converts it.

Negative:

- Supersedes the built transaction endpoint behavior — the young Transactions feature is refactored (account-scoped → period-scoped for flow; account endpoint narrows to savings movements).
- Concurrent confirms (phone + desktop) now contend on a single period stream. Accepted at solo volume via Marten optimistic-concurrency retry.
- A chatty ledger now shares one stream with the lifecycle events. Accepted: the user chose one stream over a dedicated sibling ledger for simplicity.
- The `MonthProjection` rebuild logic changes its actuals source.

Neutral:

- Account streams still exist and remain balance-bearing — for savings movements only.
- The flat per-entry projection that backed ADR-0003 payload comparison and transaction-level reads is now sourced from `FlowRecorded` (for the activity/Transactions screen) and from account movements (for balances), rather than a single account-stream `TransactionRecord`.

## Alternatives Considered

1. **Dedicated month-ledger stream separate from the period aggregate** (two aggregates per period sharing the key). Rejected by the user in favor of one stream: simpler, fewer streams, everything-about-a-month in one place. The mixed-concerns/contention trade-off is accepted.
2. **A single per-owner spending stream** (account-less but not per-period). Rejected: grows unbounded over the life of the app; the per-period stream is bounded and matches the close model.
3. **Reintroduce a spending/checking account type.** Rejected: ADR-0009 deliberately refused account types, and flow entries need no balance.
4. **Keep transactions on account streams, add a non-balance "spending" account.** A variant of (3); same rejection.
5. **Actuals as projection-only state (no events).** Rejected: actuals are user-authored ledger entries that deserve auditability and idempotency — they need a stream, like the override and target already do (ADR-0007 Alternative 1).

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.

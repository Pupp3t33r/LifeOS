# ADR-0006: Budget aggregate (light monthly category targets)

## Status

Accepted

Date: 2026-06-15

## Context

The Wallet app is oriented as a **planner**, not a tracker (see `apps/wallet/PLAN.md`). Its Home surface is a monthly savings canvas that needs per-category spend targets to make projected spending meaningful. The user has chosen **light budgets** over YNAB-style envelope budgeting: monthly targets per category, no rollover, no enforcement, no moving money between categories.

Forces at play:

- Categorization in LifeOS is **dual-track** (per `apps/wallet/PLAN.md`): a purchase is either *domain-linked* (`serviceType=books, externalId=<bookId>` — implicit categorization) or *free-text tagged* (`coffee`, `groceries` — explicit). There is no fixed category list and no category CRUD.
- A budget must therefore target either a domain category or a tag — the same dual-track shape.
- Budgets are month-scoped: a target applies to one (year, month) and resets next month. No envelope-style accumulation.
- Budgets are read-mostly from the Wallet's perspective: the user sets targets, then sees actual-vs-target as the month progresses.
- Per ADR-0005, transactions do not carry good references — domain linkage lives on the richer aggregate (PurchaseOrder). Budget actuals must therefore aggregate across transactions *and* settled purchase orders.
- Multi-currency (ADR-0008) means budget targets and actuals are in a single currency (the user's chosen display currency, which equals their primary savings currency); line items in other currencies are converted at calculation time.

## Decision

Add a **`Budget` aggregate** to Money with the following shape:

| Field | Type | Notes |
|---|---|---|
| `BudgetId` | Guid | Client-assigned per ADR-0003 |
| `OwnerId` | string | From JWT `sub` (ADR-0004) |
| `Year`, `Month` | int | The month this target applies to |
| `CategoryKey` | string | Either `domain:<serviceType>` (e.g., `domain:books`) or `tag:<tagtext>` (e.g., `tag:coffee`) |
| `TargetAmount` | Money | In the user's display currency (ADR-0008) |

Stream key: `budget/{OwnerId}/{Year}/{Month}/{CategoryKey}`.

### Events

- `BudgetTargetSet` — create or overwrite the target for a (month, category).
- `BudgetTargetCleared` — remove the target.

No `actuals` live on the aggregate. Actuals are computed by a projection that consumes `TransactionRecorded`, purchase-order settlement events, and the tag index (see "Tag storage" below).

### Rollover policy

**None.** Setting a target for April does not affect May. April's under/over-spend does not flow into May's target. Each month is independent. This is consistent with the broader "each month is independent" model in ADR-0009.

### No enforcement

A budget is a target, not a constraint. Recording a transaction that exceeds a category budget succeeds; the Wallet surfaces the over-spend visually. The Money service does not reject transactions based on budget state.

## Tag storage (deferred detail)

Tags are categorization data, not financial state. The storage mechanism for tags (separate Marten documents, side table, projection-only) is **not decided by this ADR** — it is added to the deferred-decisions list in the ADR README and will be settled when the first tag-consuming feature is implemented.

What this ADR *does* mandate: budgets target tags by `CategoryKey="tag:<tagtext>"`. Whatever storage backs tags, the budget projection reads through it.

## Consequences

Positive:

- Light budgets match the planner orientation without imposing envelope-budgeting complexity.
- Dual-track `CategoryKey` cleanly supports both domain and tag categorization.
- Monthly reset keeps the model simple and matches the savings-canvas mental model.
- No enforcement means no coupling between budget state and transaction recording — budgets are pure read-side signals.

Negative:

- Users who want YNAB-style rollover or envelope workflows are not served. Accepted: this is a deliberate scope limit for v1; a future ADR can extend.
- Actuals aggregation requires a projection that joins transactions, settled POs, and the tag index. Real implementation work.
- Tag storage being deferred means the tag-budget path is partially unspecified until that sub-decision lands.

Neutral:

- Budget has its own stream — consistent with ADR-0005's pattern of giving richer domain concepts their own aggregates.

## Alternatives Considered

1. **Full envelope budgeting (YNAB-style).** Categories accumulate balances across months; users move money between categories; rollover is the default. Rejected: user explicitly chose light budgets. Envelope budgeting is a different mental model and would warrant its own aggregate family if ever adopted.
2. **No budgets at all; only top-level savings target.** Rejected: per-category visibility is part of the planning UX the user asked for. The savings canvas alone is too coarse.
3. **Budgets as a projection, not an aggregate.** Store targets in a flat table; no event sourcing. Rejected: targets are user-authored state with a meaningful lifecycle (set, edited, cleared) and belong in the event stream for auditability. Inconsistent with Money's "everything financial is event-sourced" stance.

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.

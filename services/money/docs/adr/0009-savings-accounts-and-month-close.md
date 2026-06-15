# ADR-0009: Savings accounts as the only account type

## Status

Accepted

Date: 2026-06-15

## Context

The Wallet app is a planner, not a tracker. Per `apps/wallet/PLAN.md`:

- "Current account balance" is **not** a useful concept for everyday spending — without bank integration, balance drifts and any prominent display sells false precision.
- The relevant number is monthly net flow (target/projected/actual savings), not real-time balance.
- Balances *do* matter for one specific case: **savings accounts**, where the whole point is knowing whether you can afford a big planned purchase or absorb an overspend.

Forces at play:

- ADR-0005 defines an `Account` aggregate generically (per-currency balances, owner, name). The user has now scoped this: only savings accounts exist in v1.
- Conventional personal finance distinguishes checking, savings, credit, cash — each with its own semantics. The user does not want this complexity.
- Multi-currency (ADR-0008) means the user can hold multiple savings accounts in different currencies, all of the same type.
- The user wants the savings account to **compensate for overspending**: at month close, surplus flows in; deficit draws out (ADR-0007 handles the close mechanics).
- Balance tracking for savings is **user-maintained** (no bank sync), with an editable "honesty valve" pattern: the user can override the computed balance at any time to account for untracked activity.

## Decision

### Account type scope

**All Money accounts are savings accounts.** There is no checking, credit, or cash account type. The `Account` aggregate from ADR-0005 (as revised by ADR-0008 to be single-currency) represents a savings account exclusively.

If future requirements demand other account types (e.g., a credit account for installment principal tracking), a new ADR will scope that. v1 ships savings only.

### Account balance semantics

A savings account has:

- `Balance: Money` — the current balance, single currency (ADR-0008). Computed as the sum of opening balance + recorded transactions.
- `Currency: string` — ISO 4217 (3-letter). Declared at account open; immutable.
- `OpenedAt: DateTimeOffset`.

~~- `BalanceOverride: Money?` — nullable. When set, this is the truth; otherwise `Balance` is the sum of opening balance + recorded transactions.~~ *(Removed 2026-06-15 — see amendment below.)*

The savings account balance is always transaction-derived (opening + all recorded transactions). The single honesty valve for monthly savings reconciliation is `MonthlyReview.ActualSavingsOverride` (ADR-0007), applied to the account at month close via the surplus/deficit deposit/withdrawal flow below. This avoids two overlapping override mechanisms and keeps "user-truth" at the monthly delta level where the planning UX operates.

> **Amendment (2026-06-15):** `BalanceOverride` was removed. The original rationale was an absolute-balance honesty valve on the account, but this overlaps with the monthly delta override on `MonthlyReview` (ADR-0007). The month-close flow already reconciles the account balance by applying the confirmed savings delta. One honesty valve (monthly, flow-based) is cleaner than two (absolute stock + monthly flow). If per-account absolute override is needed later, a new ADR will scope it.

### Interactions with month close (ADR-0007)

At month close, the `MonthClosed` handler computes the final savings number (`ActualSavingsOverride ?? projectedSavings`) and:

- If positive (surplus): appends a deposit transaction to the user-designated savings account for the closing month, converted to that account's currency at close-day FX rates (ADR-0008).
- If negative (deficit): appends a withdrawal transaction, same conversion.
- If zero: no transaction.

The user designates **which savings account** receives the close flow per MonthlyReview (default: their primary savings account; overridable at close time). For multi-currency users, this means the canvas may aggregate across currencies but the close flow lands in one account's currency.

### No transfers between accounts in v1

The user can record a transfer between two savings accounts as two transactions (one withdrawal, one deposit) with a `TransferId` linking them. There is no first-class Transfer aggregate in v1 — transfers are a UI convenience that produces two ledger entries. This is consistent with ADR-0005's rule that Transaction is a generic primitive, not a typed concept.

## Consequences

Positive:

- The Account aggregate stays simple: one type, one currency, one transaction-derived balance.
- The Wallet UI does not need account-type pickers or type-specific behavior.
- Multi-currency is solved by "multiple accounts," not by "one account with many balances" — matches user mental model.
- The honesty-valve override is consistent with the `ActualSavingsOverride` pattern on MonthlyReview (ADR-0007): user-truth beats computed-truth wherever a "real number" matters.

Negative:

- Users with complex finances (checking + credit + cash + investment accounts) are not served. Accepted: this is a deliberate scope limit.
- No first-class Transfer aggregate means transfer UI is purely cosmetic — two ledger entries. Weak for audit ("was this a transfer or two unrelated transactions?"). Mitigated by the `TransferId` link, which the projection can surface.
- Balance is transaction-derived; no manual override on the account. Reconciliation happens at month close via the ADR-0007 delta flow.

Neutral:

- The Account aggregate from ADR-0005 is essentially unchanged in structure; this ADR scopes its use, not its mechanics.

## Alternatives Considered

1. **Distinguish savings vs. spending accounts.** Spending accounts would be transaction sources whose balance does not matter. Rejected: adds a type distinction the user does not want. Spending/outgo can be categorized via tags and domains without an account type.
2. **Full account types (checking, savings, credit, cash).** Rejected by user explicitly. Adds setup overhead and type-specific semantics that do not serve the planner orientation.
3. **No accounts at all; only transactions.** Rejected: savings needs a persistent store with a balance, which is exactly what an account provides.

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.

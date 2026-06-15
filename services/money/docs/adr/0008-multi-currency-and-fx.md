# ADR-0008: Multi-currency CurrencyAmount value object and FX rate service

## Status

Accepted

Date: 2026-06-15

**Supersedes:** the "Multi-currency" section of [ADR-0005](./0005-aggregate-boundaries.md), which specified per-account `Dictionary<string, decimal>` balances keyed by currency code and stated that "Exchange-rate conversion and FX events are out of scope for v1." This ADR revises both: accounts become single-currency, and an FX rate service enters v1 scope.

## Context

The Wallet app must support multi-currency from day one. Concrete requirements from `apps/wallet/PLAN.md`:

- Planned purchases and payments may be in a currency different from the user's savings account or income.
- The user has multiple savings accounts, each in a different currency (ADR-0009).
- The savings canvas aggregates every line item into the user's chosen display currency for readability, while preserving the original currency for inline display ("€80 (~\$86)").
- Month-close (ADR-0007) converts surplus/deficit to the savings account's currency at close-day rates.

Forces at play:

- ADR-0005's per-account multi-currency dictionary (`Balances: Dictionary<string, decimal>`) allows one account to hold balances in many currencies at once. The Wallet UX, however, treats an account as a *single-currency store* — "my USD savings account," "my EUR savings account." Per-account multi-currency is a data model that does not match the mental model.
- Without an FX rate source, every cross-currency computation (canvas aggregation, month-close conversion, net-worth in Phase 3) is impossible. The deferred-decisions note "FX events are out of scope for v1" must be reversed.
- Free FX rate APIs exist that do not require API keys (Frankfurter, ECB-based). For a self-hosted personal app, a free source with daily refresh is sufficient.
- Per ADR-0002, dev-mode event versioning is flexible; introducing a `CurrencyAmount` value object on existing events (TransactionRecorded) is acceptable during v1 development but must be settled before any production freeze.

## Decision

### CurrencyAmount value object

Introduce a **`CurrencyAmount` value object** used everywhere a monetary amount appears:

```
public sealed record CurrencyAmount(decimal Amount, string Currency);
```

> **Naming note (2026-06-15):** This value object was originally named `Money` in this ADR. It ships as `CurrencyAmount` to avoid ambiguity with the `LifeOS.Money` service namespace. The two names are interchangeable in any earlier prose; the type is `CurrencyAmount`.

`Currency` is an ISO 4217 code (`USD`, `EUR`, etc.). `Amount` is a `decimal` with application-layer precision rules (typically 2 decimal places for display, full precision for storage and computation).

`CurrencyAmount` replaces bare `decimal` on:

- `AccountOpened` / account balance fields (now singular — see below)
- `TransactionRecorded` amount
- `RecurringPayment` amount
- `InstallmentPlan` per-payment amount
- `WishlistItem` estimated cost
- `PurchaseOrder` line item amount and total
- `Budget.TargetAmount` (ADR-0006)
- `MonthlyReview.TargetSavings` and `ActualSavingsOverride` (ADR-0007)
- `Asset.AcquiredCost` and `CurrentEstimatedValue` (ADR-0010)

### Single-currency-per-account (revises ADR-0005)

Each **Account** has exactly one currency, declared at `AccountOpened`. The `Balances` dictionary from ADR-0005 becomes a single `Balance: CurrencyAmount`. To hold USD and EUR, the user creates two accounts. This matches the Wallet UX model and simplifies balance computation (no per-currency folds inside one account).

This **supersedes** the "Multi-currency" subsection of ADR-0005. The rest of ADR-0005 (transaction-on-account-stream, aggregate taxonomy, tenancy) stands unchanged.

### FX rate service

A new background service fetches FX rates daily and stores them as projection rows:

| Field | Type | Notes |
|---|---|---|
| `Base` | string | ISO 4217 base currency |
| `Quote` | string | ISO 4217 quote currency |
| `Date` | DateOnly | The date the rate applies to |
| `Rate` | decimal | Amount of `Quote` per 1 unit of `Base` |

Source: **Frankfurter** (`https://api.frankfurter.dev/v1` or `https://api.frankfurter.app`). ECB-based, free, no API key required, daily refresh on business days.

Schedule: a Quartz cron job runs daily (configurable; default 09:00 UTC, after ECB publishes). The job fetches latest rates for a configured set of currencies (the user's’s display currency plus any currencies that appear in their accounts, transactions, or planned purchases) and upserts `FxRate` rows.

For currencies or dates not present (weekends, holidays), the projection serves the **most recent prior rate**. Forward-fill semantics.

### Rate-by-context policy

Different read contexts use different rates:

| Context | Rate used |
|---|---|
| **Projection** (savings canvas, planned purchases, recurring) | Latest known rate at query time |
| **Actuals** (transactions logged in a month) | Rate on the transaction date |
| **Month-close conversion** (ADR-0007) | Rate on `ClosedAt` date |
| **Asset valuation** (ADR-0010, Phase 3) | Latest known rate at query time |
| **Historical analytics** (Phase 5) | Rate on the relevant historical date |

When a transaction's currency matches the display currency, no conversion occurs.

## Consequences

Positive:

- Multi-currency is a first-class concept with one consistent value object across the entire domain.
- Single-currency-per-account matches the Wallet UX and simplifies balance computation.
- Frankfurter removes API-key and billing concerns; the cron job is self-contained.
- Rate-by-context policy produces honest numbers: projections use "as of now," actuals use "as of when."
- Forward-fill handles weekends and holidays without special-case logic at read time.

Negative:

- `CurrencyAmount` introduction is a refactor of existing events and code. Mitigated by ADR-0002's flexible dev-mode versioning; must be settled before v1 freeze.
- FX rate coverage is limited to ECB's published currency set (~30 currencies). Users with exotic currency needs are not served. Accepted for v1.
- The cron job is a new failure surface. Mitigation: structured logging, retry policy, alert on stale rates (no `FxRate` row within N days).
- Latest-known-rate for projections means the canvas shifts slightly day-to-day as rates move. This is honest but may surprise users. UI should label "converted at today's rate."

Neutral:

- Frankfurter publishes daily, not intra-day. For a personal finance app this is fine; for trading-grade use it would be insufficient.

## Alternatives Considered

1. **Keep ADR-0005's per-account multi-currency dictionary.** Rejected: does not match the Wallet UX model ("my USD account," "my EUR account"). Forces the UI to render multiple balances per account, which the user does not want.
2. **Per-transaction currency without an FX service.** Store currency on each transaction but never convert. Rejected: the savings canvas must aggregate into one number; without conversion it cannot.
3. **Paid FX API (Open Exchange Rates, Fixer).** Rejected: requires API key management, billing, and rate limits for a self-hosted personal app. Frankfurter's daily ECB rates are sufficient.
4. **Store FX rates as events in Marten.** Rejected: FX rates are external observed data, not user-authored domain state. They belong in a query-optimized projection/table, not the event store.

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.

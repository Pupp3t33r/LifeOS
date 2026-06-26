# ADR-0015: FX rate sourcing — Belarusbank card rates, plain BackgroundService, client rate cache

## Status

Accepted

Date: 2026-06-26

**Supersedes:** the **FX rate service** and **Rate-by-context policy** sections of [ADR-0008](./0008-multi-currency-and-fx.md). The `CurrencyAmount` value object and single-currency-per-account decisions of ADR-0008 are unaffected and still stand.

**Amends:** [ADR-0013](./0013-user-preferences-and-configurable-month.md) — adds a `DefaultSpendingCurrency` field to the UserPreferences document.

## Context

ADR-0008 chose **Frankfurter** (ECB mid-market rates) fetched by a **Quartz daily cron**, with a rate-by-context policy. Implementation work surfaced three forces that revise that choice:

- **The primary user is in Belarus and spends mostly via card.** ECB mid-market rates do not reflect what actually leaves the account on a card transaction. Belarusbank publishes card buy/sell rates at `https://belarusbank.by/api/kurs_cards`, which match real card spending far more closely. For honest actuals, these are the relevant rates for the pairs they cover.
- **The project's minimalist stance** (root `AGENTS.md`: avoid libraries where the platform suffices) makes a Quartz dependency unnecessary for a single hourly job. A plain .NET `BackgroundService` with a `PeriodicTimer` is enough.
- **No server→client push is planned** (offline-first; the Wallet client already polls read models). FX rates are simply another read model the client syncs on its own cadence.

A further constraint from `apps/wallet/PLAN.md`: **no false precision.** A converted number the user cannot trace back to a rate is dishonest. The user must be able to see which rate (and how fresh) produced any conversion.

## Decision

### Multi-source rate service with precedence

The FX service fetches from two sources and stores them in the existing `FxRate` projection, which gains a **`Source`** column:

| Field | Type | Notes |
|---|---|---|
| `Base` | string | ISO 4217 base currency |
| `Quote` | string | ISO 4217 quote currency |
| `Date` | DateOnly | The date the rate applies to |
| `Rate` | decimal | Amount of `Quote` per 1 unit of `Base` |
| `Source` | string | `belarusbank` \| `frankfurter` |

**Precedence:** for any pair, prefer the **Belarusbank** rate when published; fall back to **Frankfurter** otherwise. The international fallback exists only for pairs Belarusbank does not cover.

### Belarusbank: use the SELL side

Belarusbank `kurs_cards` publishes card **buy** and **sell** rates. v1 converts using the **SELL** rate — the bank sells the user foreign currency when they spend on card, so the sell rate is the honest cost of a foreign-currency transaction. The buy side (relevant only when receiving foreign currency, e.g. resale income) is deferred until foreign-currency income is a real case.

### Plain BackgroundService, hourly — no Quartz

The fetch runs in a single .NET **`BackgroundService` driven by a `PeriodicTimer`**, **hourly**. No Quartz, no scheduling library. The job fetches both sources for the configured currency set (display currency, spending currency, plus any currency appearing in accounts, transactions, or planned purchases), then upserts `FxRate` rows. Failures are logged structurally and retried on the next tick; a stale-rate alert fires when no row is newer than N days. **Forward-fill** (serve the most recent prior rate for weekends/holidays/gaps) is retained from ADR-0008.

### Conversion responsibility — server authoritative, client estimates

| Value | Rate used | Who converts |
|---|---|---|
| **Actuals** (recorded transactions) | SELL rate on the transaction date | **Server** — authoritative; the converted value ships in the read model |
| **Aggregates** (savings canvas total, account/budget totals) | per ADR-0008 contexts (latest for projection, transaction-date for actuals, close-date for close), SELL side | **Server** — computed in projections |
| **Projections/estimates** (recurring, planned purchases, wishlist) | latest known SELL rate | **Client** — inline decoration from its cache |
| **Pre-confirmation / offline** (a mutation not yet acknowledged by the server) | latest cached SELL rate | **Client** — a `~estimate`, replaced by the server's value on sync |

The client never produces an authoritative converted number for a stored transaction. It only **estimates** before the server confirms, and **decorates** inherently-estimated projections.

### Client rate cache

The Wallet client runs its own background poll **every 15 minutes**, pulling the `FxRate` set from the server into a local `fx_rates` cache (drift). The 15-minute cadence deliberately does not try to align with the server's hourly fetch — it just stays fresh enough. This cache powers inline projection decorations and offline/pre-confirmation estimates. No server→client push.

### Display rates in the app

The Wallet app **surfaces the applicable rates** in a low-prominence **Rates view** (reached from Settings), showing for each relevant pair: the SELL rate, its **source** (Belarusbank / Frankfurter), the **as-of date**, and a **staleness indicator** when the rate is older than the freshness threshold. This makes every conversion in the app traceable and satisfies the no-false-precision principle.

### DefaultSpendingCurrency (amends ADR-0013)

UserPreferences gains **`DefaultSpendingCurrency`**, set during onboarding and distinct from `DisplayCurrency`. It pre-selects the currency when adding an ad-hoc expense/income. The two differ in practice: a user may **display** in USD (a stable mental model) while **spending** in BYN. `DisplayCurrency` governs aggregation and rendering; `DefaultSpendingCurrency` governs only the entry default.

## Consequences

Positive:

- Conversions of real card spending reflect the rate that actually applied, not a mid-market approximation.
- One hourly `BackgroundService` removes the Quartz dependency for a job that never needed it.
- Server-authoritative actuals mean the inline value of a synced transaction always matches the aggregate — no reconciliation drift; the client's only conversion math is the unavoidable optimistic/offline estimate.
- A visible Rates view makes the app's money math auditable by the user.
- `DefaultSpendingCurrency` removes the per-entry friction of correcting the currency for users whose spending and display currencies differ.

Negative:

- Belarusbank is a second external dependency with its own (undocumented, informal) API shape and uptime; the fetch must tolerate its outages and fall back gracefully.
- Two sources mean the rate a user sees can change source over time (Belarusbank adds/drops a pair), which the Rates view must label to avoid confusion.
- A 15-minute client poll plus an hourly server fetch is more network chatter than a daily refresh; negligible for a personal app, noted for completeness.

Neutral:

- SELL-only conversion is an intentional v1 simplification; buy-side handling is deferred, not rejected.
- Belarusbank publishes intra-day card rates; the hourly fetch samples them. Sufficient for personal finance, insufficient for trading-grade use.

## Alternatives Considered

1. **Keep Frankfurter-only (ADR-0008).** Rejected: ECB mid-market rates misrepresent the user's actual card spending in Belarus.
2. **Keep the Quartz cron.** Rejected: a single hourly job does not justify a scheduling library; a `PeriodicTimer` `BackgroundService` is the platform-native fit.
3. **Server→client push (SignalR) for rate updates.** Rejected: no push channel exists yet, and offline-first already implies client polling; rates are just another synced read model.
4. **Client computes all conversions from a full rate cache.** Rejected: duplicates the server's rate-by-context policy client-side and risks the inline value of a transaction disagreeing with the server-computed aggregate. The client estimates only what is inherently an estimate.
5. **Reuse `DisplayCurrency` as the entry default.** Rejected: forces the wrong default for users whose spending currency differs from their display currency (the expected Belarus case).

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.

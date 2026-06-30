# Wallet App — Agent Context

> **Parent:** [Root AGENTS.md](../../AGENTS.md)  
> **Roadmap:** [PLAN.md](./PLAN.md) (full phased vision, v1 scope, deferred work)  
> **Backend:** [Money service](../../services/money/AGENTS.md) — Wallet is its primary consumer

## App Identity

**Wallet** is the personal-finance client for the LifeOS platform. It is a **planner**, not a tracker — its Home surface is a monthly savings canvas, not a transaction log. The Money service owns all financial state; Wallet is its primary (Phase 1) consumer and will host cross-domain planning features (Phase 2+) as other LifeOS services come online.

- **Dart package:** `wallet`
- **Platforms:** Android, Web, Windows, Linux (single codebase, native compile + Web WASM). macOS/iOS are technically free if ever wanted.
- **Users:** 1 primary user (solo). Family UX is Phase 4+ work; v1 has no concept of "whose money is this."

## Tech Stack

| Layer | Choice |
|---|---|
| Framework | Flutter (latest stable) |
| State management | Riverpod |
| Local database | drift (SQLite via `sqlite3_flutter_libs` on mobile/desktop; WASM backend on web) |
| HTTP client | Dio + OpenAPI codegen (`openapi-generator`, dart-dio template) consuming Money's `/openapi/v1.json` |
| Routing | go_router |
| Auth | `oidc` (Keycloak OIDC, Authorization Code + PKCE, all platforms incl. Web/Windows/Linux) + `OidcDefaultStore`/`flutter_secure_storage` (token storage). Login/registration/reset are Keycloak-hosted pages, not in-app forms — see [app/auth/README.md](./lib/app/auth/README.md). |
| Theming | Shared [`design/`](../../design/README.md) theme registry → `tokens.dart` binding → Flutter `ThemeData`. Wallet wears the **Calm** theme. Style Dictionary deferred. |
| Localization | `flutter_localizations` + `intl` with `gen-l10n` ARB files (`lib/l10n/`). **English + Russian** (matches the Keycloak login locales). The chosen language is a **client-only, device-local** preference (`LocaleStore`, secure storage) — never a Money `UserPreferences` (ADR-0013). See [docs/adr/0001-app-localization.md](./docs/adr/0001-app-localization.md). Localized incrementally per surface (onboarding first); English is the fallback. |

## Architecture

### Data and sync — read models + outbox (no client-side event sourcing)

Wallet does **not** event-source locally. The Money service is the single source of truth for all financial state. The local drift database holds:

1. **Cached read models** — server projection responses (e.g., `MonthProjection`, account balances, transaction lists). Always available offline.
2. **`pending_operations` outbox** — queued HTTP mutations with idempotency keys (per Money ADR-0003) and status (`pending` / `syncing` / `failed` / `synced`).

Offline flow — **frozen in [Wallet ADR-0004](docs/adr/0004-offline-first-sync.md)** (authoritative; the summary below must track it):
- **Writes always go through the outbox** — online and offline alike, one uniform path. The UI returns when the local row commits; a drainer replays it. (No "POST directly when online" special case.)
- **Reads are stale-while-revalidate** — render the cache instantly, revalidate in the background, swallow network errors so offline reads stand.
- **Pending work is shown and counted in the view, never written to the cache.** A queued op is overlaid from the outbox at read time (and counts toward figures like the period net), deduped by client id once confirmed; the cache holds only server-confirmed truth. The in-flight portion is surfaced honestly (a self-erasing "includes −$X syncing" caption + "Syncing" rows).
- **Replay outcomes:** 2xx/409 → `synced` (409 = already applied, ADR-0003); transient/offline → stays `pending`; other 4xx → `failed` (server-rejected) — **excluded from every figure**, surfaced as resolve-me, never folded into a calculation.

The period flow ledger is the first read model wired this way — see [`features/money/data/drift/README.md`](lib/features/money/data/drift/README.md) for how it lands in practice (and its known issues).

**Hard rule:** no client-side aggregates, no client-side projections, no client-side event log; Money's business rules run once, on the server. (Display-time arithmetic over already-signed figures — summing line totals into a net — is presentation, not domain logic; ADR-0004 §1/§5 draws the line.)

### Feature modules

Wallet is structured as a single app with feature modules:

```
lib/
  main.dart
  app/                     (shell: auth, nav, theme, sync orchestration)
    auth/
    navigation/
    sync/
    theme/
  features/
    money/                 (Phase 1: the only feature area)
      data/
        drift/             (drift tables, DAOs)
        api/               (generated dio client from OpenAPI)
        outbox/
      domain/              (Dart models mirroring Money's read models)
      ui/
        month_overview/    (Home — savings canvas)
        recurring/
        wishlist/
        purchase_orders/
        transactions/
        budgets/
    <future_features>/     (Phase 2+: links to Books, Board Games, etc.)
  shared/                  (cross-feature: widgets, utils)
```

Each feature owns its drift tables, API client pieces, and Riverpod providers. Cross-feature calls go through the shell (auth/nav/sync), never feature-to-feature.

### Categorization

Per Money [ADR-0024](../../services/money/docs/adr/0024-category-model.md) and `apps/wallet/PLAN.md`, categorization is a **managed category list** (the dual-track tag model is superseded — there are no tags):

- **System categories** ship built-in and domain-linked: **Books**, **Board Games**, **Video Games**. Immutable — the user cannot create/delete/rename them.
- **User categories** are fully user-managed (create/rename/delete). Delete = soft-archive (retired from the picker; history keeps resolving).

A line carries **one `CategoryId`** (nullable = uncategorized). `GET /api/money/categories` returns the overlay `system ∪ user`. A line may also carry a separate `ExternalRef` — a direct link to a *specific* domain object (Phase 2+, when Books/Board Games come online); when its service matches a system category, the `CategoryId` auto-defaults and the user may override. Domain deep-linking / inline preview goes through the Gateway BFF.

Budgets target a `CategoryId` (Money [ADR-0025](../../services/money/docs/adr/0025-budget-period-centric-and-category-targeted.md)). There are no tags and no `domain:`/`tag:` strings.

### Multi-currency rendering

Per `apps/wallet/PLAN.md`: render multi-currency values as **original + converted inline** (e.g., "€80 (~$86)") in the user's chosen display currency. The display currency is an explicit user preference (`UserPreferences.DisplayCurrency`, Money ADR-0013) — it **defaults** to the currency of the first savings account opened, but the user may change it independently of account topology. (This supersedes the earlier "display currency equals the user's primary savings account currency"; the primary account's currency is the default, not a live derivation. Which account receives the month-close flow is a separate setting — see Money ADR-0009.)

## Coding Standards

- **1 file per Dart class** (matching the broader LifeOS rule of one type per file).
- **Riverpod providers per feature** — co-locate with the feature, not in a global `providers/` folder.
- **Vertical slice per screen** — `ui/<screen>/` contains widgets, controllers, and any screen-local state.
- **No business rule duplication.** If a rule feels like it needs to run client-side (e.g., validation), it already runs server-side; do not re-implement. Local validation is limited to input shape, not domain invariants.
- **Structured logging** — every drift sync, every API call, every outbox drain logs structured fields (`operation_id`, `status`, `trace_id` if available).
- **OpenTelemetry** — HTTP and drift calls emit spans when configured.

## Conventions Specific to Wallet

- **Money value object in Dart** mirrors `Money(decimal Amount, string Currency)` from the Money service. Always pass the pair, never a bare `double` or `num`.
- **Editable honesty valves** are first-class UI patterns: the period's "actual savings" via an `UnaccountedFlowRecorded` gap entry (Money [ADR-0026](../../services/money/docs/adr/0026-actuals-honesty-and-savings-movements.md) — the UI may say "set actual savings to $X"; under the hood a signed gap entry is recorded so **actual = Σ flows**), and `CurrentEstimatedValue` on Assets (Money [ADR-0010](../../services/money/docs/adr/0010-asset-aggregate.md)). The user-truth beats computed-truth wherever a "real number" matters. (The old `ActualSavingsOverride` god-number is removed — ADR-0026; and there is no per-account `BalanceOverride` — it was removed in ADR-0009; account balances are movement-derived.)
- **Solo-only in v1** — no UI for "whose money is this," no shared accounts, no permissions. The data model is family-aware (every request carries `OwnerId` from JWT `sub`), but the UI is single-user.
- **Theme from the shared registry, don't hardcode.** Wallet wears the **Calm** theme. The Dart binding is vendored at `lib/app/theme/calm_tokens.dart` (a Flutter package can't import files outside its own `lib/`, unlike the CSS binding Keycloak bind-mounts); `app/theme/app_theme.dart` maps it into light/dark `ThemeData`. Reference the theme (or `CalmTokens`) for colors/fonts/radii rather than literals. Token values are owned by `design/themes/calm/tokens.json` — change them there and mirror into the binding (see [design/README.md](../../design/README.md)). The Keycloak sign-in wears Calm via the CSS binding, so login and app stay visually consistent.

## Anti-Patterns

- ❌ **Do not event-source locally.** No drift event log, no client-side projections. The Money service is the source of truth.
- ❌ **Do not duplicate business rules.** Validation, balance computation, currency conversion policy — all server-side. Client validates shape only.
- ❌ **Do not call services directly bypassing the Gateway.** All HTTP goes through `/api/money/*` (or `/app/v1/*` for BFF-composed endpoints).
- ❌ **Do not call other services from feature modules directly.** Cross-domain composition (e.g., enriching a Books purchase with book metadata) goes through the Gateway BFF.
- ❌ **Do not track balances for non-savings accounts.** There are no non-savings accounts in v1 (Money ADR-0009).
- ❌ **Do not display "current account balance" prominently.** The savings canvas is Home, not a balance sheet.
- ❌ **Do not introduce per-feature Flutter projects.** Wallet is one app. Features are modules inside it.

## Phases (summary — see [PLAN.md](./PLAN.md) for detail)

| Phase | Scope |
|---|---|
| **1 (v1)** | Solo money planner: monthly savings canvas, recurring, installments, wishlist→PO→transaction, light budgets, transactions (frequency up to user), multi-currency, savings accounts |
| **2** | Domain-linked purchases: Books + Board Games come online; deep-linking; enriched wishlist/PO UI |
| **3** | Inventory & net worth: Asset aggregate (Money ADR-0010); BFF `/app/v1/inventory`; resale values; net-worth surface |
| **4** | Family / multi-user: shared accounts, his/hers/ours, per-user budgets, permissions |
| **5** | Long-term analytics: year+ trends, savings rate, category analysis, "should I buy this over time" advisor |

---

*Last updated: 2026-06-29*

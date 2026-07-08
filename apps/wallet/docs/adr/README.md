# Wallet App — Architecture Decision Records

This folder holds architecture decisions specific to the **Wallet** Flutter app — client-side concerns (UI, local storage, on-device preferences, navigation) that are not owned by any backend service. Server-side financial decisions live in the [Money ADR log](../../../../services/money/docs/adr/README.md); login/identity decisions live in the [Keycloak ADR log](../../../../aspire/LifeOS.AppHost/keycloak/docs/adr/README.md).

Each ADR is a single markdown file following the [Nygard format](https://adr.github.io). To start a new one, copy the format of an existing ADR here or [Money's `template.md`](../../../../services/money/docs/adr/template.md). Once an ADR is marked **Accepted**, its body is frozen — supersede via a new ADR, never edit.

## Accepted

| # | Title | Date |
|---|---|---|
| [0001](./0001-app-localization.md) | In-app localization — `flutter_localizations` + `intl` (ARB), English + Russian, client-only device-local locale | 2026-06-29 |
| [0002](./0002-navigation-and-information-architecture.md) | Navigation & information architecture — the current-period cockpit and a four-destination shell (Home · Activity · Accounts · Wishlist) _(Plan reinstated by 0005; shell revised by 0006 — Accounts folds into Home, Wishlist confirmed)_ | 2026-06-29 |
| [0003](./0003-category-colour-system.md) | Category colour system — a curated 12-colour Calm palette, client-assigned, light/dark | 2026-06-29 |
| [0004](./0004-offline-first-sync.md) | Offline-first sync — cached read models, a write outbox, idempotent replay; pending shown & counted via overlay but never cached | 2026-06-30 |
| [0005](./0005-plan-destination-and-planning-views.md) | The Plan destination — a three-view planning home (List · Board · Budget); reinstates Plan, assigns wishlist items; backlog management & nav slotting left open | 2026-07-08 |
| [0006](./0006-acquisition-flow-placement-and-nav-shell-revision.md) | Acquisition-to-ownership flow placement + revised nav shell — orders on Home (period-decoupled arriving strip), Accounts folds into Home, Wishlist its own tab, collection → domain apps, net worth → future Stats (amends 0002, relates 0005 + Money 0030/0031/0032) | 2026-07-08 |

## Related decisions housed elsewhere

| Where | Decision | Relevance |
|---|---|---|
| [Keycloak ADR-0001](../../../../aspire/LifeOS.AppHost/keycloak/docs/adr/0001-login-page-internationalization.md) | Login page internationalization (EN + RU) | The login surface that precedes the app; Wallet ADR-0001 matches its locales for a consistent sign-in → app experience. |
| [Money ADR-0013](../../../../services/money/docs/adr/0013-user-preferences-and-configurable-month.md) | `UserPreferences` (server-owned config) | Wallet ADR-0001 explains why the UI language is **not** a `UserPreferences` field — it changes nothing the server computes. |
| [Money ADR-0014](../../../../services/money/docs/adr/0014-auth-session-lifetimes-and-passkeys.md) | Auth UX — sessions, passkeys, biometric app-lock | Establishes the client-only, device-local preference precedent (`AppLockStore`) that the locale store follows. |

## Numbering

ADRs here are numbered in acceptance order, **monotonic and never reused**, independent of every other ADR folder (this folder starts at 0001).

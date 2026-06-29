# Keycloak (Identity) — Architecture Decision Records

This folder holds architecture decisions specific to the **Keycloak identity provider** for LifeOS — realm configuration (`lifeos-realm.json`) and the hosted login/account themes (`themes/lifeos/`). These decisions are cross-cutting: they shape how every LifeOS surface (Wallet, web, each service) authenticates, so they do not belong to any single service.

Each ADR is a single markdown file following the [Nygard format](https://adr.github.io). To start a new one, copy the format of an existing ADR here or [Money's `template.md`](../../../../../services/money/docs/adr/template.md). Once an ADR is marked **Accepted**, its body is frozen — supersede via a new ADR, never edit.

## Accepted

| # | Title | Date |
|---|---|---|
| [0001](./0001-login-page-internationalization.md) | Login page internationalization — English + Russian, realm-level i18n | 2026-06-29 |

## Related auth decisions housed elsewhere

Two auth decisions predate this folder and live in the **Money** ADR log, where they were originally recorded as "the platform's auth-decision lineage." Per the freeze rule they are **not** moved or rewritten; they are cross-referenced here so this folder is a complete index of identity decisions:

| Where | Decision | Why it lives there |
|---|---|---|
| [Money ADR-0004](../../../../../services/money/docs/adr/0004-zero-trust-jwt-validation.md) | Zero-trust JWT validation | The *decision* is Money-local (Money re-validates tokens itself). It references the Keycloak realm but is a service-side defense-in-depth posture, not a Keycloak-config decision — correctly Money-scoped. |
| [Money ADR-0014](../../../../../services/money/docs/adr/0014-auth-session-lifetimes-and-passkeys.md) | Auth UX — session lifetimes, passkeys, biometric app-lock | Genuinely cross-cutting (realm config + Wallet client + service validation). It was parked in Money before this folder existed and is frozen; new Keycloak/identity decisions land here instead. |

## Numbering

ADRs here are numbered in acceptance order, **monotonic and never reused**, independent of every service's ADR numbering (this folder starts at 0001).

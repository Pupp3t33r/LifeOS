# ADR-0001: Blazor Hybrid stack — MAUI (Android) + Blazor Web App (web) sharing an RCL

## Status

Accepted

Date: 2026-07-07

**Relates to:** [Root AGENTS.md](../../../../AGENTS.md) §3 (frontend stack) and §6 (app templates) — this ADR **amends** the root frontend rule to acknowledge the polyglot frontend. See also [ADR-0003](./0003-per-page-render-modes.md) and [ADR-0005](./0005-viewmodels-via-communitytoolkit-mvvm.md).

## Context

The root `AGENTS.md` fixes Flutter as the frontend ("Flutter (Wallet app — Android, Web, Windows, Linux)"). Wallet is Flutter and has a mature, ADR-frozen offline-first layer (drift cache + idempotent outbox + replay), full Keycloak OIDC (passkeys, biometric app-lock), and the Calm theme vendored — all built over many sessions.

Table is a new client for a new domain (board games). During planning, the team chose Blazor Hybrid (.NET MAUI) for it as a **deliberate polyglot-frontend experiment**: the project's explicit goal is to try different approaches across services and compare their ergonomics, AI-workflow fit, and developer experience. This is a learning project; using a second client stack is the point.

Forces at play:

- Choosing Blazor Hybrid means re-implementing auth (OIDC for web, MSAL for Android), state management, and theming from scratch — Wallet's Flutter infra does not carry over.
- The "code-sharing with the .NET backend" argument is weak here: there are no shared libraries across services (root §4.3), and the Board Games API uses Minimal APIs + EF Core, not a client SDK. So the upside is end-to-end-C# developer ergonomics, not literal code reuse.
- Modern Blazor (.NET 8+, and this project is on .NET 10) supports a Razor Class Library shared between a MAUI Blazor Hybrid host and a Blazor Web App host, with per-page render modes — so "web + Android" does not force a single render strategy.
- Table is online-only in Phase 1 (ADR-0004) and a collection manager (not a planner), so it does not need Wallet's elaborate offline-first outbox. The re-implementation cost is bounded.

## Decision

Table is a **Blazor Hybrid app**: a shared **Razor Class Library (RCL)** holds all UI (pages, components, ViewModels, services), consumed by two thin hosts — a **.NET MAUI Blazor Hybrid** host (Android native; Windows available) and a **Blazor Web App** host (web). The frontend is now **polyglot**: Flutter for Wallet, Blazor Hybrid for Table. This amends the root `AGENTS.md` frontend rule by exception (recorded in the root file's stack table + a Blazor app template alongside the Flutter one).

- **RCL** = `LifeOS.BoardGames.App.RazorLib` — every page, component, ViewModel, and the `BoardGamesApiClient`. Render-mode-agnostic.
- **MAUI host** = `LifeOS.BoardGames.App.Maui` — wires `<RootComponent />` into a `BlazorWebView`; components run natively in-process (render modes do not apply).
- **Web host** = `LifeOS.BoardGames.App.Web` — Blazor Web App; assigns a render mode per page (ADR-0003).

The re-implementation cost (auth, state, theme) is accepted as the cost of the experiment. Wallet's patterns are referenced but not depended on; Table builds its own equivalents idiomatic to Blazor.

## Consequences

Positive:

- A genuine second client stack, producing a real comparison with Wallet/Flutter (the project's stated goal).
- End-to-end C# for the board-games domain — one language across the Table app and the Board Games API.
- The RCL + two-hosts shape means web and native share UI code; per-page render modes (ADR-0003) give a cheap-default/interactive-where-needed spectrum on the web.
- MAUI gives true native Android (and Windows) without a browser wrapper.

Negative:

- Auth, state management, and theming are re-implemented (no carry-over from Wallet's mature Flutter infra). Accepted cost of the experiment.
- Deviates from the root frontend rule — requires the root AGENTS.md amendment and this ADR so the deviation is sanctioned, not silent.
- MAUI Blazor Hybrid + Blazor Web App sharing an RCL has a learning curve and host-specific pitfalls (JS interop differs Server vs WebAssembly; `HttpClient` base URL differs MAUI vs Web). Mitigated by the host-agnostic-discipline rule (host services behind interfaces).

Neutral:

- The decision is scoped to Table. It does not obligate future apps to Blazor; each app picks its stack. Wallet stays Flutter.

## Alternatives Considered

1. **Flutter, as a new separate app (apps/table/).** Reuse Wallet's exact patterns (oidc, drift outbox, Calm tokens) by copying the shell. Rejected: the team explicitly wants to try Blazor Hybrid as a learning experiment and does not value cross-app uniformity.
2. **Flutter, as a Wallet feature module (apps/wallet/lib/features/board_games/).** Rejected: mixes a finance planner UI with a collection UI, and the host/guest roles don't fit Wallet's solo-first shell. Also rejected because it forgoes the experiment.
3. **Decide the app later, API only.** Rejected: the stack decision is the thing being decided now; deferring loses the learning goal. The API plan is stack-agnostic regardless.

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.

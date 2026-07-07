# Table App — Agent Context

> **Parent:** [Root AGENTS.md](../../AGENTS.md)  
> **Roadmap:** [PLAN.md](./PLAN.md) (phased vision, scope, deferred work)  
> **Backend:** [Board Games service](../../services/board-games/AGENTS.md) — Table is its primary consumer

## App Identity

**Table** is the board-game collection client for the LifeOS platform. The host uses it to build and manage their collection (search the catalog → add as owned/wishlisted), enrich it (expansions, accessories, sleeves), track lifecycle (sold / given away / play sessions), and — later — share it with guests. The Board Games service owns all collection/catalog state; Table is its primary consumer.

Table is a **deliberate polyglot-frontend experiment**: the Wallet app is Flutter, Table is **Blazor Hybrid (.NET MAUI)**. The point is to try a different client stack end-to-end, learn its ergonomics, and compare. This deviates from the root `AGENTS.md` frontend rule and is recorded in [ADR-0001](./docs/adr/0001-blazor-hybrid-stack.md) + a root AGENTS.md amendment.

- **Solution:** `LifeOS.BoardGames.App.*` (RCL + MAUI host + Web host)
- **Platforms:** Android (native via MAUI), Web (Blazor Web App). Windows native is available via MAUI but not a Phase 1 priority.
- **Users:** 1 host in v1. Guests exist in the backend model (`Collection.HostUserId` + `ShareToken`, [Board Games ADR-0005](../../services/board-games/docs/adr/0005-host-guest-authorization.md)) but the guest UX is a later phase. The app is the host's control surface.

## Tech Stack

| Layer | Choice |
|---|---|
| Framework | .NET MAUI Blazor Hybrid (Android native) + Blazor Web App (web), sharing a Razor Class Library (RCL) for all UI |
| UI components | FluentUI Blazor (`Microsoft.FluentUI.AspNetCore.Components`) |
| Theming | Board Games' own theme (distinct from Calm) in the shared [`design/`](../../design/README.md) registry — name TBD. CSS binding drives FluentUI/web; a small native-color partial covers MAUI-native surfaces. |
| State management | CommunityToolkit.Mvvm (`ObservableObject` / `RelayCommand`, source-gen) — shared ViewModels across MAUI + Blazor (ADR-0005) |
| HTTP client | Typed `HttpClient` via `IHttpClientFactory` (no Refit, no codegen) |
| Offline | **None in Phase 1** — online-only. Local caching (read-only, via Dapper) is a later possibility, decided once there's a working app to profile (ADR-0004) |
| Auth | OIDC against the `lifeos` realm. Web: same-origin via the Gateway. Android: MSAL.NET broker. New public client `table-app` (PKCE, no secret). |
| Routing | Blazor router (`@page`) in the RCL |
| Localization | .NET `IStringLocalizer` (English first; add locales incrementally) |

## Architecture

### Project shape — RCL + two thin hosts

```
apps/table/
  LifeOS.BoardGames.App.RazorLib/    # ALL UI: pages, components, ViewModels, services
  LifeOS.BoardGames.App.Maui/        # MAUI Blazor Hybrid host (Android + Windows)
  LifeOS.BoardGames.App.Web/         # Blazor Web App host (web)
  docs/adr/
```

The **RCL holds everything** — Razor pages/components, `CollectionViewModel`/etc. (CommunityToolkit.Mvvm), the `BoardGamesApiClient` (typed HttpClient), and any future local-cache service. The two hosts are thin shells that wire `<RootComponent />` into a `BlazorWebView` (MAUI) / `Routes.razor` (Web) and register host-specific services.

### Render modes — per page

The RCL components are **render-mode-agnostic**; the Web host assigns a mode per page/route (ADR-0003):

- **Static SSR + Enhanced Navigation** — the default for read-heavy host pages (collection list, catalog search results, game detail, guest read-only). Cheap, smooth (DOM-diff navigation), no WASM download, no persistent WebSocket.
- **InteractiveServer** (`@rendermode InteractiveServer`) — for light interactivity (forms, the sleeve editor, accessory-binding UI).
- **InteractiveWebAssembly** — deferred. Only if a page needs true offline execution later.

The MAUI host runs all components natively in-process inside the `BlazorWebView` — render modes don't apply there.

**Host-agnostic discipline:** components must not hardcode a render mode or call host-specific APIs directly (JS interop differs Server vs WebAssembly; `HttpClient` base URL differs MAUI vs Web). Host-provided services sit behind interfaces (`IApiClient`, `IPlatformInfo`) resolved per host. This keeps the RCL genuinely shared.

### Auth

- **Web:** OIDC via the Gateway (same-origin — the Gateway reverse-proxies `/realms/*` and serves the app, no CORS). Short online session (mirrors Wallet's web session policy).
- **Android (MAUI):** MSAL.NET broker for the authorization-code + PKCE flow; tokens in the platform secure store.
- **Client:** new public client `table-app` in the `lifeos` realm (PKCE S256, no secret), with an audience mapper so tokens validate against the Board Games API. The Board Games API accepts `board-games-api` (and, for future Wallet→Board Games BFF calls, `money-api`) audiences.

### No offline in Phase 1 (ADR-0004)

Table is **online-only** in Phase 1 — both MAUI and Web assume connectivity. There is no local SQLite store and no outbox. If a read cache is added later, it will be a read-only SQLite cache queried via **Dapper** (not EF Core — keeps the client lightweight and avoids a second EF model). The decision is deferred until a working app reveals which reads are worth caching.

## Coding Standards

- **1 file per class** (matching the broader LifeOS one-type-per-file rule).
- **ViewModels co-located with their feature** in the RCL, not in a global folder.
- **Vertical slice per screen** — `Pages/<screen>/` holds the page, its components, and its ViewModel.
- **No business-rule duplication.** Validation and invariants run server-side (Board Games full DDD); the client validates input shape only.
- **Host-agnostic RCL.** No render-mode hardcoding; host differences behind interfaces.
- **Structured logging** on every API call; OpenTelemetry spans when configured.

## Conventions Specific to Table

- **Host-first.** The signed-in user is the collection's host. The app does not surface guest mode in Phase 1, even though the backend model supports it.
- **Theme from the shared registry, don't hardcode.** Table wears the board-games theme (name TBD) from `design/themes/<name>/`. FluentUI's design tokens are overridden by the theme's CSS binding. Reference tokens, not color literals.
- **Acquisition cost is display-only here.** Money owns financial truth; Table shows a denormalized acquisition cost on a `CollectionItem` but does not compute on it.

## Anti-Patterns

- ❌ **Do not couple the RCL to a render mode or a host.** No `@rendermode` in the RCL; host-specific APIs behind interfaces.
- ❌ **Do not add an offline store / outbox in Phase 1.** Online-only by decision (ADR-0004); revisit only with a profiled need.
- ❌ **Do not call the Board Games service bypassing the Gateway.** All HTTP goes through `/api/board-games/*` (or `/app/v1/*` for future BFF-composed endpoints).
- ❌ **Do not call other services from feature modules directly.** Cross-domain composition goes through the Gateway BFF.
- ❌ **Do not duplicate business rules.** Validation, sleeve coverage, accessory-binding invariants — all server-side. Client validates shape only.
- ❌ **Do not introduce per-platform or per-feature app projects.** One app, RCL + hosts; features are modules inside the RCL.

## Phases (summary — see [PLAN.md](./PLAN.md) for detail)

| Phase | Scope |
|---|---|
| **0 (v1)** | Scaffold + auth + Calm-themed empty shell; catalog search + collection CRUD (host); expansions + accessories; sleeves; plays |
| **5** | Guests — ShareToken read access (likely a lightweight web surface) |
| **6** | Money integration — wishlist ID passing to Money; consumption of `AssetSold`/`AssetTracked` (backend-driven) |
| **7** | Scores — score tracking + guest write surface |

---

*Last updated: 2026-07-07*

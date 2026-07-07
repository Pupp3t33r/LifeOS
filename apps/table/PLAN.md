# Table App — Plan

> **Purpose:** This file is the evolving roadmap for the Table Blazor Hybrid app. It captures the phased vision, scope, deferred work, and key design decisions. It is **not** frozen (unlike ADRs). Update freely as work progresses.
>
> **Related:** [Table AGENTS.md](./AGENTS.md) for stable conventions; [Board Games PLAN.md](../../services/board-games/PLAN.md) for the backend roadmap that drives this work.

---

## 1. App vision

Table is the **board-game collection manager** for the LifeOS platform. Its primary job is answering, for the host:

- *"What games do I have, want, or used to have?"* — browse/search the catalog, add to the collection, track lifecycle (own / wishlist / sold / given away).
- *"What's in/with this game?"* — expansions, accessories (with their binding kinds), and sleeve coverage (what's still unsleeved).
- *"How much have I played it?"* — play sessions with duration and player count.

It is a **deliberate polyglot-frontend experiment**: Wallet is Flutter, Table is Blazor Hybrid. The goal is to try a different client stack end-to-end and learn its ergonomics, contrasted with Wallet. Where Wallet is a *planner* with an offline-first outbox, Table is a *collection manager* that is online-only in Phase 1 — a leaner client surface to start.

The Board Games service is the single source of truth for all collection/catalog state. Table mirrors its read models and issues mutations; it does not re-implement domain rules.

---

## 2. Design principles

1. **Host-first, guest-aware.** The signed-in user is the host. The app does not surface guest mode in Phase 1, but the backend model carries it (`ShareToken`) so guests arrive without a migration.
2. **Online-only to start.** No local store, no outbox. The simplest viable client. Offline/caching is a later, profile-driven decision.
3. **Host-agnostic RCL.** All UI lives in the Razor Class Library; the MAUI and Web hosts are thin. Components never hardcode a render mode.
4. **Per-page render modes.** Static + Enhanced Navigation for read-heavy pages; InteractiveServer for forms. The cheapest mode that works per page.
5. **Own theme, not Calm.** Board Games gets its own visual identity in the shared design registry. FluentUI Blazor is the component set; the theme overrides its tokens.
6. **No business-rule duplication.** Sleeve coverage, accessory-binding invariants, ownership transitions — all server-side. The client validates input shape only.

---

## 3. Phase 0 (v1) — Host collection manager

### Platforms

Android (native via MAUI Blazor Hybrid) and Web (Blazor Web App). Windows native is available via MAUI but not a Phase 1 priority.

### Screens / areas

| Area | Job | Backend (Board Games) |
|---|---|---|
| **Collection** | Browse the host's items; filter by status/type; open detail | `Collection` + `CollectionItem` (ADR-0002/0005) |
| **Catalog search** | Find a game in the external catalog; add as owned/wishlisted | `CatalogGame` + `ICatalogSource` (ADR-0002/0003) |
| **Game detail** | Catalog properties (players, time, mechanics, image) + the host's ownership/lifecycle; expansions; accessories bound; sleeve coverage | `CatalogGame` + `CollectionItem` |
| **Accessories** | Manage accessory bindings (Inseparable / Standalone / PrimaryWithReuse / Series) | `AccessoryBinding` (ADR-0004) |
| **Sleeves** | Sleeve inventory + per-game sleeving status + coverage view | `SleeveBatch` + `SleevingStatus` (ADR-0006) |
| **Plays** | Log play sessions; per-game history | `PlaySession` |

### Out-of-scope for v1

- Guests / sharing (Phase 5)
- Money integration (Phase 6)
- Scores / ratings (Phase 7)
- Offline / local cache (deferred, ADR-0004)
- WebAssembly offline pages (deferred, ADR-0003)

### Backend prerequisite

v1 requires the Phase 1 Board Games backend (see [Board Games PLAN.md](../../services/board-games/PLAN.md) §3). Sequencing is **backend-first**: Board Games features land, then Table UI is built against the real API. No mock/stub parallel track.

### Auth

- New public client `table-app` in the `lifeos` realm (PKCE S256, no secret), with an audience mapper (`board-games-api`).
- **Web:** OIDC same-origin via the Gateway. Short online session.
- **Android (MAUI):** MSAL.NET broker; tokens in platform secure store.
- Reuse Wallet's per-platform session-scope precedent (short web session, long native session) once the client is wired.

---

## 4. Phase 5 — Guests

- Host generates/regenerates a `ShareToken` from the app.
- Guests access via a share link — likely a **lightweight read-only web surface** (Static SSR + Enhanced Nav) rather than cramming a guest mode into the host app shell.
- Guest write (rating/score) waits for Phase 7.

The decision between "guest mode inside Table" vs "separate read-only web page" is deferred to when Phase 5 starts.

---

## 5. Phase 6 — Money integration

- The host picks a collection item and sends its id to Money (Table calls Money's API with an `ExternalReference("board-games", id)`). Mostly a Wallet/Planner concern, but Table is the source of the id.
- Table reflects Money's `AssetSold` / `AssetTracked` outcomes (consumed by the Board Games backend, surfaced in Table as status changes). Backend-driven; Table needs no new logic beyond displaying the result.

---

## 6. Phase 7 — Scores

A proper score-tracking feature (per-session scores, ratings, winner history). Designed fresh once the collection model is stable. This is also the forcing function for the guest write surface (guests rate / score).

---

## 7. Sequencing summary

```
0  Scaffold + auth + themed empty shell
    ↓
0  Collection + catalog search (host CRUD)
    ↓
0  Expansions + Accessories (binding UI)
    ↓
0  Sleeves (inventory + coverage)
    ↓
0  Plays
    ↓
[v1 complete]
    ↓
5  Guests (ShareToken read access)
    ↓
6  Money integration (UI passing + backend events)
    ↓
7  Scores (own design pass; opens guest write surface)
```

---

## 8. Open implementation questions (not ADR-level)

- Theme name + vocabulary (board-games theme in `design/themes/`).
- Whether guests get a read-only web page vs a guest mode inside the Table app (Phase 5 decision).
- Card-size vocabulary display (standard / mini / tarot / etc.) — labels and ordering.
- Accessory-binding UI shape for `PrimaryWithReuse` (primary picker + usable-with multi-select).
- Whether the web host ships in Phase 0 or arrives once the RCL is stable. Cheap to add later since the RCL is host-agnostic by design.
- Windows native: ship via MAUI or defer (Android + Web are the stated targets).

---

## 9. What Table will NOT do (anti-scope)

- ❌ **Offline-first / outbox in Phase 1.** Online-only by decision (ADR-0004).
- ❌ **Duplicate domain rules.** Sleeve coverage, accessory invariants, ownership transitions — server-side only.
- ❌ **Per-platform or per-feature app projects.** One app: RCL + MAUI host + Web host.
- ❌ **Guest write before Phase 7.** Guests are read-only until scores land.

---

*Last updated: 2026-07-07*

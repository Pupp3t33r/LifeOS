# Board Games Service — Plan

> **Purpose:** This file is the evolving roadmap for the Board Games service. It captures the phased vision, scope, deferred work, and build order. It is **not** frozen (unlike ADRs). Update freely as work progresses.
>
> **Related:** [Board Games AGENTS.md](./AGENTS.md) for stable conventions; [Board Games ADRs](./docs/adr/) for frozen architectural decisions; [Table PLAN.md](../../apps/table/PLAN.md) for the consumer-app roadmap that drives this work.

---

## 1. Service vision

Board Games is the **collection manager** for the LifeOS platform's board-game domain. Its job is to answer two questions for the host:

1. *"What games do I have, want, or used to have?"* — the ownership/lifecycle over items (games, expansions, accessories, sleeves).
2. *"What is this game?"* — rich reference data (player count, play time, mechanics, themes, card composition) sourced externally and kept fresh by sync.

It does **not** own financial state (Money does) or time/planning (Planner does). It is the source of truth that Money references via `ExternalReference("board-games", ...)`. The depth is in the **relationships** — expansion trees, accessory attachment modes, sleeve coverage — not in event-sourced financial invariants.

---

## 2. Design principles

1. **Catalog ≠ Collection.** Reference data is immutable and externally sourced; ownership/lifecycle is the host's mutable state referencing it. Re-syncing the catalog never disturbs ownership (ADR-0002).
2. **Full DDD, hand-rolled.** Aggregates enforce invariants; value objects remove invalid state at construction; domain events are the future Kafka seam. No DDD libraries — the patterns are written explicitly so they're transparent (ADR-0001/0003).
3. **Lean stack.** EF Core is the only "framework" beyond ASP.NET Core. Wolverine arrives only when Kafka lands. Minimal APIs, not Wolverine.Http (ADR-0003).
4. **Host-first, guest-aware.** The data model carries `HostUserId` + `ShareToken` from day one (ADR-0005); the guest UX is a later phase.
5. **External source is swappable.** The catalog source sits behind `ICatalogSource`; BGG is one implementation. Rate limits / fallbacks / alternatives are a pluggable decision (ADR-0003).

---

## 3. Phase 1 feature build order

Each item is a discrete feature slice following the per-feature folder convention (`Features/<Domain>/<Action>.cs`). Phase 1 is **host-only** (no guest UX); the data model is guest-aware.

### 3.0 Scaffold

- Two projects: `LifeOS.BoardGames.Api` + `LifeOS.BoardGames.Tests`, under `services/board-games/`.
- `Program.cs` modelled on Money's composition (Serilog, Keycloak JWT, OTel via ServiceDefaults, FluentValidation endpoint filter) but with EF Core + Npgsql instead of Marten.
- `BoardGamesDbContext` + first migration.
- AppHost registration (`postgres.AddDatabase("board-games-db")` + project), Gateway route (`/api/board-games/*`), Keycloak clients (`board-games-api`, `table-app`), solution entry.
- Dockerfile (copy Money's, swap paths).
- This proves the full vertical (auth → endpoint → DB) before any domain work.

### 3.1 Catalog + on-demand lookup (ADR-0002/0003)

- `Domain/Catalog/CatalogGame.cs` aggregate: `(Source, ExternalId)` key, title, year, image, player range, play-time range, complexity weight, BGG rating, mechanics/themes (JSONB), card composition.
- `External/Catalog/ICatalogSource.cs` + `BggCatalogSource.cs` (typed HttpClient, never throws) + `BggOptions.cs` + a pure `BggXmlParser` (unit-testable).
- `Features/Catalog/`: `GET /catalog/search?q=`, `GET /catalog/{id}`, `POST /catalog/{id}/refresh`.
- Day 1 depth: on-demand lookup only — search + thing detail cached into `CatalogGame` on add. No scheduled collection/plays sync.

### 3.2 Collection + lifecycle (ADR-0001/0002/0005)

- `Domain/Collections/Collection.cs` aggregate (`HostUserId`, `ShareToken`) and `CollectionItem.cs` entity (`Status: Wishlist|Owned|Sold|GivenAway|Removed`, acquisition/disposition fields, optional `CatalogGameId`).
- Ownership lifecycle as a state machine on `CollectionItem` (methods: `MarkAsOwned`, `MarkAsSold`, `GiveTo`, `Remove`...), each validating the transition.
- `Features/Collection/`: add item (from catalog or ad-hoc), update status, list/filter, get detail.
- Idempotency via client-assigned ids (root §4.5) — same model as Money ADR-0003.

### 3.3 Expansions + Accessories (ADR-0004)

- Expansion→base linking (a `CollectionItem` of type Expansion with a parent reference).
- `AccessoryBinding` link table with `Kind` discriminator: `Inseparable` (one target, follows on sale), `Standalone` (no binding), `PrimaryWithReuse` (primary target + usable-with list), `Series` (franchise key).
- `Features/Collection/`: attach/detach accessory endpoints; the binding invariants enforced in the domain.

### 3.4 Sleeves (ADR-0006)

- `Domain/Sleeves/`: `SleeveBatch` (host inventory: brand/size/color/count), `CardComposition` (per-catalog-game card sizes + counts), `SleevingStatus` (per collection-item + card size: sleeved count).
- Sleeve coverage as a derived read (cards needed − cards sleeved per size) — computed at read, not stored as a snapshot.
- `Features/Sleeves/`: batch CRUD, set sleeving status, coverage view.

### 3.5 Plays

- `Domain/Plays/PlaySession.cs` aggregate (`PlayedAt`, `DurationMinutes`, `PlayerCount`, `Notes`, link to the played item).
- `Features/Plays/`: log a play, list history (per game / per period).

---

## 4. Phase 5 — Guests

- Share-token flow: host generates/regenerates a `ShareToken`; any authenticated LifeOS user presenting it gets **read-only** guest access to that collection (ADR-0005).
- Guest read endpoints (`GET /shared/{shareToken}/...`).
- Guest write surface (rating, score) is gated behind the score-tracking feature.

---

## 5. Phase 6 — Money integration

Deferred until the collection model is stable. Likely shape (to be confirmed in its own ADR when it lands):

- **UI-driven wishlist passing** — the user picks a collection item in the Table app and sends its id to Money (the Table app calls Money's API with an `ExternalReference`). No new Board Games endpoint needed.
- **Kafka consumption** — Board Games consumes Money's `AssetSold` / `AssetTracked` events to mark items no longer owned / newly tracked.
- **Possible published events** — `board-games.collection.added` / `.disposed` for Money to back-reference. Topic/partition conventions per root §5.
- This is the phase that pulls in Wolverine (ADR-0003): `WolverineFx` + `WolverineFx.EntityFrameworkCore` (outbox) — retrofitted without touching the Minimal-API HTTP layer.

---

## 6. Phase 7 — Scores

A proper score-tracking feature (per-session scores, ratings, winner history). Deliberately deferred — it deserves its own design pass once the collection model is stable. It is also the forcing function for the guest write surface.

---

## 7. Sequencing summary

```
3.0 Scaffold                        (projects, AppHost, Gateway, Keycloak, Dockerfile)
    ↓
3.1 Catalog + on-demand lookup      (ICatalogSource, BGG, search/detail cached)
    ↓
3.2 Collection + lifecycle          (Collection, CollectionItem, ownership state machine)
    ↓
3.3 Expansions + Accessories        (AccessoryBinding, four kinds)
    ↓
3.4 Sleeves                         (SleeveBatch, CardComposition, SleevingStatus, coverage)
    ↓
3.5 Plays                           (PlaySession logging)
    ↓
[Phase 1 backend complete → Table app work begins]
    ↓
5  Guests                           (ShareToken read access)
    ↓
6  Money integration                (UI passing + Kafka events; Wolverine pulled in)
    ↓
7  Scores                           (designed fresh; opens guest write surface)
```

---

## 8. Forcing functions for deferred decisions

| Deferred decision | Forcing function |
|---|---|
| Catalog source choice (BGG vs alternative) + sync depth | 3.1 catalog feature — `ICatalogSource` keeps it pluggable |
| Wolverine outbox conventions (topic naming, partition keys) | 6 Money integration — first Kafka event |
| Money integration shape (UI vs events vs both) | 6 Money integration — decided in its own ADR then |
| Score tracking model | 7 Scores — own design pass |
| Guest write surface | 7 Scores — guests rate / score |
| Strongly-typed IDs (Vogen) | Only if ID-mixing bugs actually bite |
| Specifications pattern | Only if query dimensions explode into many composable permutations |

---

## 9. Open implementation questions (not ADR-level)

These can be settled during implementation, not before:

- Card-size vocabulary (standard / mini / tarot / mini-euro / etc.) — a fixed enum or a string?
- Whether sleeve coverage is a server-computed read or an app-side computation.
- Accessory `Series` key — free-text franchise string vs a normalized series entity.
- Whether plays can track multiple distinct games in one session (a game night) or always one item per session.
- Acquisition cost currency — stored denormalized on `CollectionItem` (Board Games) vs only in Money. Likely both: Board Games shows it, Money owns the financial truth.

---

*Last updated: 2026-07-07*

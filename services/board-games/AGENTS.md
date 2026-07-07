# Board Games Service — Agent Context

> **Parent:** [Root AGENTS.md](../../AGENTS.md)  
> **Depth:** Deep  
> **Stack:** .NET 10, PostgreSQL + EF Core, full DDD  
> **Roadmap:** [PLAN.md](./PLAN.md) (current state, feature build order)

## Service Identity

Board Games owns the board game collection: the **catalog** of games (reference data sourced externally) and the host's **ownership/lifecycle** over items (games, expansions, accessories, sleeves). It does NOT own financial state — Money does (see root AGENTS.md §2). Board Games is the source of truth for *"what is this game"* and *"what is my relationship with it"*; Money references Board Games via `ExternalReference("board-games", ...)`.

**Owned domains (bounded contexts):**

- **Catalog** — externally-sourced reference data (BGG or alternatives) keyed by `(Source, ExternalId)`; refreshed on sync, never coupled to ownership (ADR-0002)
- **Collection** — the host's ownership/lifecycle over items (`Wishlist → Owned → Sold / GivenAway / Removed`); accessories and expansions are items with relationships; one host per collection (ADR-0005)
- **Accessories** — accessory binding semantics: `Inseparable` / `Standalone` / `PrimaryWithReuse` / `Series` (ADR-0004)
- **Sleeves** — sleeve inventory + per-game card composition + sleeving status; inventory is not consumed by sleeving (ADR-0006)
- **Plays** — play sessions (date, duration, player count)

## Tech Stack

| Component | Choice |
|---|---|
| Persistence | EF Core + Npgsql (migrations; owned types for value objects; `IEntityTypeConfiguration<T>` keeps mapping out of entities) |
| Architecture | Full DDD — aggregates, value objects, domain events, bounded contexts (ADR-0001) |
| HTTP | Plain Minimal APIs (`app.MapGet/Post`); FluentValidation via a small `IEndpointFilter` → `ProblemDetails` |
| Messaging | None yet — **Wolverine is deferred** to the Money-integration phase; retrofitted without touching the HTTP layer (ADR-0003) |
| Logging | Serilog (JSON output) |
| Observability | OpenTelemetry via `LifeOS.ServiceDefaults` |
| External catalog | `ICatalogSource` abstraction; BGG is one implementation, swappable (ADR-0003) |

## Decisions

Architecture decisions are recorded as ADRs in [`docs/adr/`](./docs/adr/). The full index lives in [`docs/adr/README.md`](./docs/adr/README.md).

| # | Decision |
|---|---|
| [0001](./docs/adr/0001-full-ddd-and-domain-folder.md) | Full DDD for Board Games; relaxes root rule "Domain folder only in Money" |
| [0002](./docs/adr/0002-catalog-vs-collection-separation.md) | Catalog (immutable external reference) vs Collection (ownership/lifecycle) as separate bounded contexts |
| [0003](./docs/adr/0003-lean-stack.md) | Lean stack — EF Core only, plain Minimal APIs, FluentValidation via filter, Wolverine deferred, DDD building blocks hand-rolled (no Vogen / Ardalis.Specification / Stateless / MediatR) |
| [0004](./docs/adr/0004-accessory-binding-model.md) | Accessory binding — Inseparable / Standalone / PrimaryWithReuse / Series via a binding link table |
| [0005](./docs/adr/0005-host-guest-authorization.md) | Host/guest authorization — `Collection.HostUserId` + `ShareToken`; any authenticated LifeOS user = guest via token; host-only in Phase 1 |
| [0006](./docs/adr/0006-sleeve-tracking-model.md) | Sleeve tracking — `SleeveBatch` + `CardComposition` + `SleevingStatus`; inventory not consumed by sleeving |

## Service-Specific Standards

### Full DDD (ADR-0001)

Board Games is modelled with the full set of DDD tactical patterns, **hand-rolled** (no DDD libraries):

- **Aggregates live in `Domain/<BoundedContext>/`.** Each aggregate root enforces its own invariants. Example: `Domain/Collections/Collection.cs`, `Domain/Catalog/CatalogGame.cs`.
- **Value Objects** encapsulate invariants: `PlayerCount(min, max)`, `PlayTime`, `CardCompositionEntry`, `AccessoryBinding`, `ExternalReference`, `CurrencyAmount` (mirrors Money's). Mapped via EF Core owned types.
- **State machine for the ownership lifecycle** lives as methods on the entity (`item.MarkAsSold(disposition)` validates the transition and throws on invalid). The transitions are domain logic, not a generic library's config.
- **Domain events** are raised on entities, gathered by the DbContext at `SaveChangesAsync`, and dispatched in-process. They are the future Kafka seam (deferred).
- **Repositories** are concrete, one per aggregate root. **No generic `IRepository<T>`.**
- **Strongly-typed IDs are NOT used** — plain `Guid` properties with clear names (`CollectionItemId`, `CatalogGameId`). Revisit only if ID-mixing bugs actually bite.
- **Specifications are NOT used** — query logic lives in named repository methods.

The `Domain/` folder is permitted here despite the root rule limiting it to Money — see ADR-0001. This sets the precedent that "Deep" services may opt into full DDD.

### Catalog vs Collection separation (ADR-0002)

Catalog data (externally sourced) is kept separate from ownership state:

- **`CatalogGame`** is reference data keyed by `(Source, ExternalId)`. Re-syncing updates catalog rows without touching ownership. Multiple hosts reference the same catalog row.
- **`CollectionItem`** references a `CatalogGame` (for games/expansions) and carries the host's ownership/lifecycle. For ad-hoc accessories with no catalog entry, `CatalogGameId` is null and the item self-describes (title, notes).

### Cross-service references

Board Games uses `ExternalReference(string ServiceType, Guid ExternalId)` (its own copy — no shared library across services, per root rule). When Money later links to a board game, `ServiceType = "board-games"` and `ExternalId` = the `CollectionItem.Id`. Board Games never queries Money or any other service over HTTP — cross-service coordination is via Kafka events only (deferred).

### Feature Organization

```
Features/
  Catalog/
    SearchCatalog.cs              (endpoint + request/response)
    GetCatalogGame.cs
    RefreshCatalogGame.cs
  Collection/
    AddItem.cs
    UpdateItemStatus.cs
    GetCollection.cs
    ...
  Sleeves/
    ...
  Plays/
    ...
Domain/
  Common/                         (Entity, ValueObject, AggregateRoot, IDomainEvent base types)
  Collections/                    (Collection aggregate, CollectionItem, AccessoryBinding)
  Catalog/                        (CatalogGame aggregate, CardComposition VO)
  Sleeves/                        (SleeveBatch, SleevingStatus)
  Plays/                          (PlaySession)
Data/
  BoardGamesDbContext.cs
  Configurations/                 (IEntityTypeConfiguration<T>)
  Repositories/
External/
  Catalog/                        (ICatalogSource, BggCatalogSource, CatalogSyncService, BggOptions)
```

One type per file, file named after the type. No `Controllers/`, no generic `Services/` or `Repositories/` folders.

### External catalog sync

Mirror Money's FX pattern (`services/money/.../Fx/`): an `ICatalogSource` typed-HttpClient that **never throws** (catch external failures → return empty), a `BggOptions` POCO bound from config, and a `CatalogSyncService : BackgroundService` driven by a `PeriodicTimer`. The source is swappable — BGG is one implementation behind the interface; an alternative/fallback can be added without touching the domain. Day 1: **on-demand lookup only** (search + detail cached on add). Ongoing collection/plays sync is deferred.

### No Marten / No Event Sourcing

- **Do not use Marten.** EF Core is the only data access tool. Event sourcing is isolated to Money (root AGENTS.md §2).
- Use EF Core LINQ for reads. Migrations applied via `dotnet ef` (a pre-deploy step in prod — no runtime auto-create in non-Development environments).

## Events Owned

None yet. Board Games will eventually consume Money's `AssetSold` / `AssetTracked` events (Phase 3, deferred) and may publish collection/wishlist events for Money to reference. All cross-service messaging is deferred to the Money-integration phase. When the first event lands, Wolverine is pulled in (ADR-0003) and topic/partition conventions follow root AGENTS.md §5 (e.g. `board-games.collection.added`, partition key = entity id, consumer group `<consumer>-board-games`).

## Anti-Patterns

- ❌ **Do not use Marten.** EF Core only. Event sourcing is Money's domain.
- ❌ **Do not pull in Wolverine before the Kafka phase.** Plain Minimal APIs + EF Core + in-process domain events for now (ADR-0003).
- ❌ **Do not add DDD libraries** (Vogen, Ardalis.Specification, Stateless, MediatR). Patterns are hand-rolled (ADR-0003).
- ❌ **Do not store financial state.** Money owns cost. `CollectionItem` may carry a denormalized acquisition cost + an `ExternalReference` to Money; Board Games does not compute on financial state.
- ❌ **Do not couple the Catalog to ownership.** Catalog is reference data; Collection references it (ADR-0002).
- ❌ **Do not put business logic in API endpoints.** Endpoints are thin: load aggregate → call domain method → save.
- ❌ **Do not create generic repositories.** One concrete repository per aggregate root.
- ❌ **Do not mix bounded contexts internally.** `Domain/Catalog/` does not reach into `Domain/Plays/` internals; cross-context coordination goes through well-defined seams.
- ❌ **Do not use MediatR.** (root rule) Plain handlers / direct calls.
- ❌ **Do not query another service's database or call it over HTTP.** Cross-service is Kafka-only (deferred).

---

*Last updated: 2026-07-07*

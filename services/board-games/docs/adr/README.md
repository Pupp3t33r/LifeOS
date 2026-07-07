# Board Games Service — Architecture Decision Records

This folder holds all architecture decisions specific to the Board Games service. Each ADR is a single markdown file following the [Nygard format](https://adr.github.io). Once an ADR is marked **Accepted**, its body is frozen — supersede via a new ADR, never edit.

See [`template.md`](./template.md) to start a new ADR.

## Accepted

| # | Title | Date |
|---|---|---|
| [0001](./0001-full-ddd-and-domain-folder.md) | Full DDD for Board Games — relaxes root rule "Domain folder only in Money" | 2026-07-07 |
| [0002](./0002-catalog-vs-collection-separation.md) | Catalog vs Collection separation (immutable external reference vs ownership/lifecycle) | 2026-07-07 |
| [0003](./0003-lean-stack.md) | Lean stack — EF Core only, plain Minimal APIs, FluentValidation via filter, Wolverine deferred, hand-rolled DDD building blocks | 2026-07-07 |
| [0004](./0004-accessory-binding-model.md) | Accessory binding model — Inseparable / Standalone / PrimaryWithReuse / Series via a binding link table | 2026-07-07 |
| [0005](./0005-host-guest-authorization.md) | Host/guest authorization — Collection.HostUserId + ShareToken; any authenticated user = guest via token | 2026-07-07 |
| [0006](./0006-sleeve-tracking-model.md) | Sleeve tracking — SleeveBatch + CardComposition + SleevingStatus; inventory not consumed by sleeving | 2026-07-07 |

## Superseded

| # | Title | Superseded by | Notes |
|---|---|---|---|

## Deferred decisions

The following decisions have been identified but **intentionally deferred** until they can be grounded in real implementation work. Each will become an ADR when its forcing function arrives.

| Decision | Deferred until |
|---|---|
| Wolverine outbox conventions (topic naming, partition keys) | The first cross-domain event is wired (Money-integration phase) |
| Catalog source choice (BGG vs alternative vs fallback) and sync depth (on-demand vs scheduled collection/plays sync) | First catalog feature lands — the `ICatalogSource` seam lets this stay a pluggable decision |
| Money integration shape (UI-driven wishlist ID passing; `AssetSold`/`AssetTracked` consumption; published events) | Money-integration phase — Board Games Phase 6 |
| Score tracking (per-session scores, ratings) | Designed as its own feature once the collection model is stable |
| Guest write surface (guests rating games, writing scores) | Follows the score-tracking feature |

## Numbering

ADRs are numbered in acceptance order (the order in which they were marked Accepted). Numbers are **monotonic and never reused**. Per the per-service ADR convention, Board Games' numbering is independent of other services — this folder starts at 0001.

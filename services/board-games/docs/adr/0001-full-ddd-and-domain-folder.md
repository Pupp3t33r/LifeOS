# ADR-0001: Full DDD for Board Games — relaxes root rule "Domain folder only in Money"

## Status

Accepted

Date: 2026-07-07

**Relates to:** [Root AGENTS.md](../../../../AGENTS.md) §6 ("Domain folder only in Money"), §10 (service depth). Amends the root rule by exception.

## Context

The root `AGENTS.md` §6 limits the `Domain/` folder to the Money service, with the rationale *"Other services do not need `Domain/` — `Entities/` or `Data/` is fine."* That rationale was written when only Money existed, and it rested on an implicit assumption: only the event-sourced, invariant-heavy Money service is complex enough to justify a rich domain layer.

Board Games is the second service to be built, and it is explicitly rated **"Deep"** in the root service-depth table (§10): *"Relational model, expansion trees, sleeve MRP, shipment tracking. Real domain logic. EF Core + migrations."* During planning, the team committed to modelling it with full DDD as a deliberate learning exercise (this is a learning project for distributed-systems patterns), and because the domain genuinely has the complexity to make the patterns pay off:

- Multiple sub-domains (catalog, collection, accessories, sleeves, plays) with distinct ubiquitous languages — natural bounded contexts.
- Relationships with real invariants (accessory binding rules, sleeve coverage constraints, ownership lifecycle transitions).
- Cross-entity logic (sleeve coverage = inventory + card composition + sleeving status) that belongs in a domain service, not a handler.
- A future Kafka integration (Money events) for which domain events are the natural seam.

Forces at play:

- This is a learning project — using richer patterns where they fit is part of the point.
- Board Games is **not** event-sourced (root §2 isolates ES to Money). Full DDD here means tactical DDD over EF Core, not event sourcing.
- Applying DDD blindly everywhere would be cargo-cult; the decision is to apply it where it earns its place (see Decision).

## Decision

Board Games is modelled with the **full set of DDD tactical patterns**, and gets a `Domain/` folder organised by bounded context (`Domain/Catalog/`, `Domain/Collections/`, `Domain/Sleeves/`, `Domain/Plays/`). This **relaxes the root rule "Domain folder only in Money"** by exception for Board Games.

The patterns are applied where they have genuine payoff:

- **Aggregates** with enforced invariants (`Collection` enforces same-collection binding targets; `CatalogGame` enforces valid ranges).
- **Value Objects** that remove invalid state at construction (`PlayerCount(min,max)`, `PlayTime`, `CardCompositionEntry`, `AccessoryBinding`, `ExternalReference`, `CurrencyAmount`).
- **Domain events** raised on entities, dispatched in-process now, published to Kafka later.
- **Domain services** for cross-aggregate logic (sleeve coverage calculation, catalog enrichment).
- **Concrete repositories** (one per aggregate root; no generic `IRepository<T>`).
- **State machine** for the ownership lifecycle, as methods on the entity.

And explicitly **not** applied (cargo-cult, skipped):

- Event sourcing (ES stays isolated to Money — root §2).
- Separate microservices per bounded context (one service, internal BC separation).
- A pure persistence-ignorant domain with a separate mapping layer (EF Core 7+ owned types / backing fields / `IEntityTypeConfiguration<T>` is "DDD-enough").

This sets a precedent: **"Deep" services may opt into full DDD.** The root rule's intent — "don't impose a Domain folder on shallow services that don't need it" — is preserved; the exception is scoped to services whose depth justifies it.

## Consequences

Positive:

- The ownership lifecycle, accessory binding, and sleeve coverage invariants are enforced in one place and unit-testable in isolation.
- Bounded contexts keep the catalog (externally synced reference data) decoupled from ownership state, so re-syncing never disturbs the host's collection.
- Domain events make the future Money-integration phase a contained addition, not an architecture rewrite.
- The pattern is a useful learning vehicle for DDD over EF Core (contrasted with Money's DDD-over-event-sourcing).

Negative:

- More code than an anemic-model CRUD service — VOs, aggregate methods, repository classes. Justified by the domain's density and the learning goal.
- A `Domain/` folder in a non-Money service means the root rule must be read as "Deep services may opt in," not "Money only." Mitigated by this ADR recording the exception explicitly.

Neutral:

- EF Core entities are not perfectly persistence-ignorant (they lean on EF Core 7+ features: private setters, backing fields, owned types). This is the pragmatic "DDD-enough" line; a separate mapping layer was considered and rejected.

## Alternatives Considered

1. **Anemic models + `Entities/` folder (follow the root rule literally).** Rejected: the ownership lifecycle, accessory binding kinds, and sleeve coverage are genuine domain logic that belongs in the model, not scattered across handlers. The "Deep" depth rating and the learning goal both push toward richer modelling.
2. **Full DDD everywhere, including a separate mapping layer and pure domain.** Rejected: a separate mapping layer is ceremony without payoff given EF Core 7+'s support for private setters, backing fields, and owned types. The pragmatic line is drawn at "DDD-enough."
3. **Event sourcing (full DDD + Marten).** Rejected hard: root §2 isolates event sourcing to Money. The domain doesn't have the financial-invariant complexity that justifies replay/projections, and Board Games is explicitly rated CRUD-over-EF-Core.

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.

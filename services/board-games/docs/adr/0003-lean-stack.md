# ADR-0003: Lean stack — EF Core only, plain Minimal APIs, Wolverine deferred, hand-rolled DDD

## Status

Accepted

Date: 2026-07-07

**Relates to:** [ADR-0001](./0001-full-ddd-and-domain-folder.md) (full DDD). Contrasts with [Money ADR-0011](../../../money/docs/adr/0011-wolverine-http-conventions.md) (Wolverine.Http) — Board Games does **not** follow Money's HTTP convention.

## Context

Board Games is the second .NET service. Money's stack (Marten + Wolverine + Wolverine.Http + Wolverine.Http.Marten) was chosen because Money uses event sourcing and benefits from Wolverine's aggregate-handler workflow (`[WriteAggregate]` / `[ReadAggregate]` load-modify-append over Marten streams). That workflow is the forcing function for Wolverine.Http there.

Board Games is **not** event-sourced (root §2) and has no Kafka traffic in Phase 1. The aggregate-handler workflow that justifies Wolverine.Http does not apply. The remaining Wolverine.Http benefits (auto-transaction policy, FluentValidation middleware) are either already provided by EF Core's `SaveChangesAsync` (transactional per call) or trivially replaced by a small endpoint filter.

Meanwhile the project explicitly values trying different approaches across services (polyglot-by-experiment) over uniformity, and prefers a lean stack where the DDD patterns are transparent rather than hidden behind libraries.

Forces at play:

- No event sourcing, no Kafka in Phase 1 → Wolverine's main value (messaging + outbox + aggregate handlers) is dormant.
- Money's FX sync (`services/money/.../Fx/`) is the proven template for the BGG catalog sync — a plain `BackgroundService` + typed `HttpClient` + `PeriodicTimer`, no library.
- A learning project benefits from hand-writing the DDD building blocks once, rather than reaching for a library that hides them.

## Decision

Board Games runs a **lean stack**: EF Core + Npgsql is the only "framework" beyond ASP.NET Core. Specifically:

| Concern | Choice |
|---|---|
| Persistence | EF Core + Npgsql (owned types for VOs, `IEntityTypeConfiguration<T>` for mapping) |
| HTTP | Plain Minimal APIs (`app.MapGet/Post`); FluentValidation via a small reusable `IEndpointFilter` that returns `ProblemDetails` on failure |
| Messaging | **None in Phase 1.** Wolverine is pulled in only at the Money-integration phase (Phase 6), retrofitted without touching the HTTP layer |
| DDD building blocks | **Hand-rolled.** No Vogen, no Ardalis.Specification, no Stateless, no MediatR |
| External catalog | `ICatalogSource` abstraction (mirror of Money's `IFxRateSource`); BGG is one implementation |

**Hand-rolled DDD patterns** (written explicitly, in `Domain/Common/`):

- Base `Entity`, `ValueObject`, `AggregateRoot` types.
- Domain events raised on entities, gathered by the DbContext at `SaveChangesAsync`, dispatched in-process now (and to Wolverine's outbox later).
- The ownership lifecycle as a **state machine written as methods on the entity** (`item.MarkAsSold(disposition)` validates the transition and throws on invalid). Transitions are domain logic, not a generic library's config.
- Concrete repositories, one per aggregate root; **no generic `IRepository<T>`**, **no specifications**.

**Explicitly dropped** (deferred or skipped):

- **Strongly-typed IDs (Vogen).** Plain `Guid` properties with clear names. Revisit only if ID-mixing bugs actually bite.
- **Specifications (Ardalis.Specification).** Named repository methods instead.
- **Stateless.** The state machine lives in the entity.
- **MediatR.** Banned by root §4.1; plain handlers / direct calls.

**Wolverine retrofit (Phase 6):** when the first Kafka event lands, pull in `WolverineFx` + `WolverineFx.EntityFrameworkCore` (outbox tied to `SaveChanges`). The Minimal-API HTTP layer is untouched — Wolverine.Http is *not* adopted. The root §4.10 rule permits plain Minimal APIs; Wolverine.Http is "permitted for services using Wolverine's aggregate handler workflow," which Board Games is not.

## Consequences

Positive:

- One framework (EF Core) to learn and reason about; the domain layer is pure C# with no external DDD library hiding the mechanics.
- No build-time code generation (Wolverine compiles handlers at startup) — faster cold builds, easier debugging.
- The retrofit path for Wolverine is contained: messaging is additive, HTTP stays as-is.
- Contrasts usefully with Money (Wolverine-heavy ES) — a genuine polyglot-within-.NET comparison.

Negative:

- More hand-written code for the DDD building blocks (base types, event gathering, state-machine methods). Justified by the learning goal and the transparency.
- Lost compile-time ID type-safety (no Vogen) — mitigated by naming + code review + tests.
- When Wolverine lands, the team must resist migrating HTTP to Wolverine.Http for "consistency" — the decision is that they stay different (polyglot-by-experiment).

Neutral:

- The FluentValidation endpoint filter is ~15 lines, applied per route group. Replaces Wolverine.Http.FluentValidation middleware with an equivalent.

## Alternatives Considered

1. **Adopt Wolverine now (Money-style, for uniformity).** Rejected: ~95% of Wolverine's value is on the messaging side, which is dormant until Phase 6. The HTTP-side benefits are marginal and fully replaced by Minimal APIs + a filter. Wolverine is designed to be retrofitted, so deferring is low-risk. The team explicitly does not value cross-service uniformity here.
2. **Wolverine.Http now, messaging later.** Rejected: the aggregate-handler workflow that justifies Wolverine.Http doesn't apply (no Marten). Plain Minimal APIs are the root rule's *preferred* path; adopting Wolverine.Http for its own sake adds opacity for no payoff.
3. **Vogen for strongly-typed IDs.** Rejected for now: the per-type EF Core value-converter boilerplate isn't worth it until ID-mixing bugs actually bite. A contained later addition if needed.
4. **Ardalis.Specification for the query side.** Rejected: the query dimensions are finite (status/type/sleeved/has-accessories); named repository methods are clearer than a spec combinator for a fixed set.

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.

# ADR-0011: Wolverine.Http endpoint and handler conventions

## Status

Accepted

Date: 2026-06-16

**Partially supersedes:** the *endpoint mechanism* of [ADR-0001](./0001-rest-contract-approach.md), which specified Minimal APIs ("code-first REST with Minimal APIs in vertical-slice feature folders"). ADR-0001's core decision — code-first OpenAPI as documentation derived from code, not a frozen spec — stands unchanged. Only the framework used to author endpoints changes here.

## Context

Money adopted the Critter Stack (Marten for event sourcing, Wolverine for messaging) per the AGENTS.md tech-stack table. The Account and Transaction features were migrated from Minimal APIs to Wolverine.Http (commit `94e4de2`). Wolverine.Http is not a thin wrapper over Minimal APIs — its endpoints are code-generated handlers with their own conventions for parameter binding, return-value handling, validation, and event-sourcing integration via the Marten "aggregate handler workflow."

These conventions are non-obvious, and getting them wrong fails at runtime (or at code-generation time on first request) rather than at compile time. During the migration, three were violated and shipped broken:

- Returning `(CreationResponse, AccountResponse)` published the response body to the message bus ("no routes can be determined for AccountResponse") and returned the wrong body, because Wolverine treats the **first** returned value as the HTTP resource and every **subsequent** tuple element as a cascading message.
- Emitting a domain event via a `ref TransactionRecorded` parameter threw `UnResolvableVariableException` at code-generation time on every request — Wolverine.Http handlers append events by **returning** them, not via `ref`/`out` parameters.
- FluentValidation validators were registered in DI but never executed, because Wolverine.Http does not run them unless its middleware is installed; invalid requests reached handlers and produced 500s or false success instead of 400s.

Forces at play:

- Solo developer; conventions that stay tribal knowledge get re-violated. They must be written down and frozen.
- WolverineFx 6.10 has no generic `CreationResponse<T>`, so the "201 + Location + body" shape is not available as a single return type.
- All endpoints require authorization (`RequireAuthorizeOnAll()`); failures must translate to RFC-9457 ProblemDetails.

## Decision

We will author all Money HTTP endpoints as **Wolverine.Http handlers** in vertical-slice feature folders (`Features/<Domain>/<Action>Endpoint.cs`), registered via `MapWolverineEndpoints` under the `/api` route prefix with `RequireAuthorizeOnAll()`. The following conventions are binding:

1. **Event-sourced writes use the aggregate handler workflow.** Load the aggregate with `[WriteAggregate]` (read-write, optimistic concurrency via `FetchForWriting`) or `[ReadAggregate]` (read-only). Emit new events by **returning** them — a single event, a `Wolverine.Marten.Events` collection, or a `MartenOps` side effect — as part of the handler's return tuple. Never use `ref`/`out` parameters for events.

2. **Return-value shape.** The **first** value the handler returns is the HTTP response body; **every additional tuple element is a cascading message** published through Wolverine, not part of the response. For a `201 Created` with a body, return `Microsoft.AspNetCore.Http.Results.Created(location, body)` — WolverineFx 6.10 has no `CreationResponse<T>`, and returning `(CreationResponse, body)` publishes `body` to the bus. New-stream creation that is not loading an existing aggregate may call `IDocumentSession.Events.StartStream` directly or return `MartenOps.StartStream(...)`.

3. **Validation.** Request validation is FluentValidation `AbstractValidator<T>` classes registered via `AddValidatorsFromAssemblyContaining<>`, executed by `opts.UseFluentValidationProblemDetailMiddleware()` on the Wolverine HTTP pipeline. A validation failure returns `400` ProblemDetails before the handler runs. Handlers assume their request is already structurally valid and enforce only invariants that require loaded state.

4. **Errors to ProblemDetails.** Domain/application failures throw typed exceptions (`AppException` subclasses such as `NotFoundException` and `ConflictException`, plus domain exceptions like `DuplicateTransactionException`); `ProblemExceptionHandler` maps them to RFC-9457 ProblemDetails with the correct status code. Unmapped exceptions surface as 500 — mapping gaps (e.g. Marten `ConcurrencyException`) are tracked in PLAN.md, not here.

5. **OpenAPI is unchanged in principle.** Code-first generation per ADR-0001 still holds: `Microsoft.AspNetCore.OpenApi` serves `/openapi/v1.json`, Swagger UI at `/swagger`. The document advertises the Keycloak OAuth2 scheme (ADR-0004) via a document transformer.

## Consequences

Positive:

- The aggregate handler workflow gives optimistic-concurrency-protected writes with minimal boilerplate, and is the idiomatic Critter Stack pattern.
- The specific traps are frozen, so the next feature slice (and the next agent) does not re-discover them by producing 500s.
- Vertical-slice organization is preserved; the migration is a mechanism change, not a structural one.

Negative:

- Wolverine.Http code-generates handlers; some errors (variable resolution, return shape) appear only at runtime/first request, not at compile time. Per-endpoint integration tests are therefore mandatory, not optional.
- `Results.Created` is a small divergence from a "pure" Wolverine return-type style, forced by the 6.10 API surface. Revisit if `CreationResponse<T>` becomes available.
- Developers must internalize the "first value = body, rest = messages" rule, which differs from Minimal APIs.

Neutral:

- Nothing here changes the contract-authoring philosophy (code-first) or the folder convention; only the endpoint framework.

## Alternatives Considered

1. **Stay on Minimal APIs (ADR-0001 as written).** Rejected: the service committed to Wolverine + Marten for event sourcing and the outbox; Minimal APIs would mean hand-wiring `FetchForWriting`, optimistic concurrency, and outbox transactions per endpoint — duplicating what the aggregate handler workflow provides for free.
2. **Wolverine.Http but emit events via `ref`/`out` parameters.** Rejected: not supported — fails at code generation. Returning events is the only supported mechanism.
3. **Make response DTOs inherit `CreationResponse` to get 201 + Location.** Rejected: the same DTO (`AccountResponse`) is reused by GET endpoints, where the inherited 201/Location behavior would be wrong. `Results.Created` keeps the DTO a pure resource.
4. **Custom result type/middleware to standardize 201 bodies.** Deferred: not worth the abstraction at the current endpoint count; `Results.Created` is explicit and clear.

---

**Rules:** Once this ADR is marked **Accepted**, the body is frozen. To change the decision, write a new ADR that **Supersedes** this one — do not edit this file.

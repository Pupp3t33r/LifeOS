# LifeOS — Agent Context

> **Purpose:** This file provides project-wide context for AI coding assistants.  
> **Rule:** Agents MUST read this file before generating code, proposing refactors, or answering architecture questions.  
> **Update:** Add new universal constraints here. Do not scatter rules across individual files.

---

## 1. Project Identity

**LifeOS** is a personal life-management platform built as a learning project for distributed systems, event sourcing, microservices, and polyglot architecture.

- **Owner:** Solo developer (experienced .NET, learning higher-level abstractions).
- **Deployment:** Self-hosted on a single VPS + Docker Compose. Not SaaS.
- **Users:** 1 primary user + potential family members (admin/user roles).
- **Goal:** Internalize real-world patterns (event sourcing, Kafka, CQRS, offline-first mobile) through a working system.

---

## 2. Architecture at a Glance

### Services (8 total)

| # | Service | Lang | DB | Depth | Owns | Context |
|---|---|---|---|---|---|---|
| 1 | **Gateway / BFF** | .NET | — | Thin | Routing, auth proxy, mobile composition | [Gateway AGENTS.md](services/gateway/AGENTS.md) |
| 2 | **Money** | .NET | PostgreSQL + Marten | **Very Deep** | Accounts, transactions, recurring, installments, purchase orders, wishlist, event store | [Money AGENTS.md](services/money/AGENTS.md) |
| 3 | **Books** | .NET | PostgreSQL | Medium | Hardcover sync, reading progress, preorders | TBD |
| 4 | **Board Games** | .NET | PostgreSQL | Deep | Collection, BGG sync, expansions, accessories, sleeve inventory, preorders | TBD |
| 5 | **Steam** | Rust | PostgreSQL | Shallow | Library sync, playtime hours | TBD |
| 6 | **Media** | Node / .NET | PostgreSQL | Shallow | Watchlist, TMDB/AniList sync, runtime | TBD |
| 7 | **Planner** | .NET | PostgreSQL | Medium | Evening planning read model (`remainingMinutes` only) | TBD |
| 8 | **Document Processing** | Python | TBD | Shallow | OCR, receipt parsing (deferred) | TBD |

### Key Boundaries

- **Money owns all financial state.** No other service stores cost, payment schedules, or wishlist data. Other services reference Money via `serviceType` + `externalId`.
- **Planner owns time only.** It knows `remainingMinutes` for backlog items. It does NOT know wishlists, shipment statuses, or purchase history.
- **No sync service-to-service calls.** Services communicate via Kafka events only. The Gateway may compose multiple REST calls for frontend needs.
- **Event sourcing is isolated to Money.** All other services use standard EF Core + PostgreSQL CRUD.
- **Each service owns its own cron jobs.** No centralized scheduler.

---

## 3. Technology Stack

| Layer | Choice |
|---|---|
| Runtime | .NET (latest) (primary), Rust (Steam), Python (Doc Processing), Node (Media optional) |
| Web | ASP.NET Core Minimal APIs |
| Event Store | Marten on PostgreSQL |
| Messaging (.NET) | Wolverine (Kafka transport, outbox with Marten) |
| Messaging (Rust) | `rdkafka` |
| ORM (non-ES) | EF Core |
| Auth | Keycloak (self-hosted OIDC) |
| Broker | Kafka API (Redpanda local, Kafka if clustered) |
| Gateway | YARP |
| Frontend | Flutter (Wallet app — Android, Web, Windows, Linux; see [Wallet PLAN](apps/wallet/PLAN.md)). Other web apps (Angular/React/Vue/Blazor) deferred until a forcing function arrives. |
| Mobile | Flutter (Wallet; Android is the primary mobile target) |
| Observability | OpenTelemetry → Collector → Grafana (Prometheus + Loki + Tempo) |
| Dev Orchestration | .NET Aspire |
| CI/CD | GitHub Actions → GHCR |
| Theming | [`design/`](design/README.md) shared theme registry — per-theme `tokens.json` + platform bindings (`tokens.css` live; Flutter `tokens.dart` next). Style Dictionary deferred until a theme needs >1 generated binding. |

---

## 4. Universal Coding Standards

Rules that apply to **all** services regardless of language or stack:

1. **No MediatR.** Use Wolverine handlers in .NET. Use raw Kafka consumers in Rust.
2. **No gRPC.** HTTP REST + JSON for sync. Kafka for async.
3. **No shared class libraries across services.** Each service is self-contained. Common contracts use Protobuf (Phase 2) or JSON with agreed schemas.
4. **No distributed transactions / sagas (yet).** Use Draft status + cron cleanup until a Saga pattern ADR is written (deferred — see root `docs/adr/` when platform-wide decisions land).
5. **Idempotent endpoints.** All mutation endpoints must handle duplicate requests safely (idempotency keys or natural keys).
6. **Structured logging only.** Use Serilog with JSON output. Include `trace_id`, `span_id`, `service_name` in every log.
7. **OpenTelemetry instrumentation.** All HTTP handlers, DB calls, and Kafka producers/consumers must emit traces.
8. **Trunk-based git.** `main` only. Short-lived feature branches. No `develop` branch.
9. **Containerized by default.** Every service must have a working Dockerfile. Aspire AppHost references it.

### .NET Universal

10. **Minimal APIs, not controllers.** Use `app.MapGet`, `app.MapPost`, etc. Group routes with `app.MapGroup("/api/books")`. Wolverine.Http attribute routing (`[WolverineGet]`, `[WolverinePost]`) is permitted for services using Wolverine's aggregate handler workflow — these are static handler methods, not MVC controllers.
11. **Vertical slice or handler-per-feature.** Do not create `Controllers/`, `Services/`, `Repositories/` folders by default. Co-locate request, handler, and response.
12. **FluentValidation** for request validation. Return `ProblemDetails` on failure.

> **Per-service exceptions:** See the service's `AGENTS.md` for stack-specific rules (e.g., Money uses Marten; others use EF Core).

---

## 5. Communication Patterns

### Sync (REST)

```
Frontend / Mobile
    → Gateway (YARP)
        → Service (REST + JSON)
```

- Gateway routes by path prefix: `/api/money/*`, `/api/books/*`, etc.
- Mobile uses `/mobile/v1/*` for batch sync and optimized payloads.
- Services do NOT call each other via HTTP.

### Async (Kafka)

```
Service A (Wolverine / rdkafka)
    → Kafka Topic
        → Service B (Wolverine / rdkafka)
```

- **Event choreography only.** No central orchestrator (yet).
- **Topics are named by domain event:** `inventory.book.imported`, `money.transaction.recorded`, `planner.backlog.updated`.
- **Partition keys:** Use entity ID (e.g., `BookId`) to preserve ordering for that entity.
- **Consumer groups:** One group per service per topic. E.g., `planner-books`, `money-books`.
- **At-least-once delivery.** Handlers must be idempotent.

### Auth

- Keycloak realm `lifeos`.
- JWT Bearer tokens. Validate signature + expiry in Gateway.
- Pass `sub` claim as `UserId` to downstream services.
- Roles: `user` (own data), `admin` (manage family/household data).

---

## 6. File Structure Conventions

### .NET Service Template

```
services/
  <ServiceName>/
    LifeOS.<ServiceName>.Api/
      Program.cs
      appsettings.json
      Features/
        <Domain>/
          <Action>.cs              (endpoint + handler + request + response)
          <Action>Validator.cs
      <Domain or Data>/           (see service AGENTS.md)
      Dockerfile
    LifeOS.<ServiceName>.Tests/
```

### Rules

- **1 class / record / struct / enum — 1 file.** No co-locating multiple public types in a single file. Each type gets its own file named after the type.
- **No `Controllers/` folder.** Use Minimal API route registration in `Program.cs` or extension methods.
- **No generic `Services/` or `Repositories/` folders.** Use feature folders (`Features/Transactions/`).
- **Tests mirror feature structure.** `Features/Transactions/RecordExpenseTests.cs`.
- **Domain folder only in Money.** Other services do not need `Domain/` — `Entities/` or `Data/` is fine.

> **Service-specific conventions:** See each service's `AGENTS.md` for details.

### Client App Template (Flutter)

```
apps/
  <AppName>/                      (e.g., wallet)
    AGENTS.md                     (app identity, stack, conventions)
    PLAN.md                       (phased vision, scope, deferred work)
    pubspec.yaml
    lib/
      main.dart
      app/                        (shell: auth, nav, theme, sync)
      features/
        <domain>/                 (e.g., money)
          data/                   (drift tables, API client, outbox)
          domain/                 (Dart models)
          ui/
            <screen>/             (vertical slice per screen)
      shared/                     (cross-feature widgets, utils)
```

**Rules:**

- **One app per consumer surface.** Wallet is one app for all platforms (Android, Web, Windows, Linux). Do not split into per-platform projects.
- **Feature modules, not per-feature apps.** Wallet's `features/money/` is the only module in Phase 1; later domains slot in as additional `features/` folders.
- **Cross-feature communication goes through the shell.** Feature modules do not call each other directly.
- **No client-side event sourcing.** Server is the single source of truth; the client caches read models and queues mutations in an outbox (see [Wallet AGENTS.md](apps/wallet/AGENTS.md)).

> **App-specific conventions:** See each app's `AGENTS.md` for details.

### Design System (shared themes)

Cross-cutting visual language lives in [`design/`](design/README.md) — a **registry of shared themes**, owned by no single service or app. **Calm** is the first theme.

```
design/
  themes/
    <theme>/
      tokens.json              (source of truth — platform-neutral)
      bindings/
        tokens.css             (web / Keycloak)
        tokens.dart            (Flutter — added when Wallet starts)
```

**Rules:**

- **`tokens.json` is authoritative.** Edit it first, then update each binding to match (sync rule in `design/README.md`). No generator yet — Style Dictionary arrives only when a theme has a second binding.
- **Per-theme vocabulary.** Each theme names its own tokens (Calm: `sage` / `clay` / `bone`); there is no shared semantic contract. A consumer is bound to one theme's names.
- **Consumers never hardcode values.** They reference the tokens. The Keycloak `lifeos` login theme (`aspire/LifeOS.AppHost/keycloak/themes/lifeos`) `@import`s a mounted `tokens.css`; the Wallet app will mirror `tokens.dart` into `ThemeData`.
- **Keycloak is the system-wide sign-in surface.** Its login theme is shared infra (lives with the AppHost), not owned by Money.

---

## 7. Testing Strategy

| Layer | Approach | Tool |
|---|---|---|
| **Domain / ES logic** | Unit tests | xUnit |
| **API contracts** | Integration tests | WebApplicationFactory + Testcontainers (PostgreSQL, Kafka) |
| **External APIs** | Record/replay | WireMock or real calls in CI with secrets |
| **Frontend** | Skip for now | Manual testing. Add Playwright/Cypress in Phase 2 if needed. |
| **Mobile** | Skip for now | Flutter widget tests optional. |

**Rule:** Every HTTP endpoint must have at least one integration test verifying the contract (200 OK, correct shape, idempotency).

---

## 8. What NOT to Do (Universal Anti-Patterns)

- ❌ **Do not put business logic in the Gateway.** Routing, auth, composition only.
- ❌ **Do not let services query each other's databases.** Use Kafka events or query your own read model.
- ❌ **Do not use distributed transactions (2PC / Saga) yet.** Draft + cron until explicitly needed.
- ❌ **Do not event-source everything.** Only Money uses Marten streams.
- ❌ **Do not build a GraphQL gateway.** REST + BFF composition is the pattern.
- ❌ **Do not share EF Core DbContext across services.** Each service owns its schema.
- ❌ **Do not use MediatR.** Wolverine replaces it.
- ❌ **Do not use MassTransit.** Licensing shift. Wolverine only.
- ❌ **Do not build Kubernetes manifests yet.** Docker Compose first.
- ❌ **Do not add gRPC.** REST only.

> **Service-specific anti-patterns:** See each service's `AGENTS.md`.

---

## 9. When to Ask for Human Input

An agent MUST pause and ask the user when:

1. **Adding a new service** (not in the 8 listed above).
2. **Changing a communication pattern** (e.g., introducing gRPC or sync service calls).
3. **Modifying the Money event model** (this is the core domain — changes ripple everywhere).
4. **Introducing a new database technology** (e.g., Redis, MongoDB, Elasticsearch).
5. **Changing auth strategy** (e.g., moving away from Keycloak, adding OAuth providers).
6. **Adding a saga or distributed transaction pattern.** This is explicitly deferred (no ADR written yet — see root `docs/adr/` when platform-wide decisions land).
7. **Scope creep that adds new domains** (e.g., "let's add a Calorie Tracker module").

---

## 10. Quick Reference: Service Depth

Use this to calibrate implementation effort:

- **Very Deep (Money):** Event sourcing, aggregates, projections, outbox, payment schedules, wishlist. Take time. Get it right.
- **Deep (Board Games):** Relational model, expansion trees, sleeve MRP, shipment tracking. Real domain logic. EF Core + migrations.
- **Medium (Books, Planner):** Standard CRUD with external API sync. Some complexity but no ES.
- **Shallow (Steam, Media, Document Processing):** HTTP client + DB insert + Kafka emit. Get it working fast. This is where polyglot lives.

---

*Last updated: 2026-06-16*  
*Maintained by: System Architect*  
*Next expected update: After Money service event model is finalized.*

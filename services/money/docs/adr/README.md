# Money Service — Architecture Decision Records

This folder holds all architecture decisions specific to the Money service. Each ADR is a single markdown file following the [Nygard format](https://adr.github.io). Once an ADR is marked **Accepted**, its body is frozen — supersede via a new ADR, never edit.

See [`template.md`](./template.md) to start a new ADR.

## Accepted

| # | Title | Date |
|---|---|---|
| [0001](./0001-rest-contract-approach.md) | REST contract approach | 2026-06-14 |
| [0002](./0002-event-versioning-strategy.md) | Event versioning strategy | 2026-06-14 |
| [0003](./0003-idempotency-via-client-assigned-uuids.md) | Idempotency via client-assigned UUIDs | 2026-06-14 |
| [0004](./0004-zero-trust-jwt-validation.md) | Zero-trust JWT validation | 2026-06-14 |

## Deferred decisions

The following decisions have been identified but **intentionally deferred** until they can be grounded in real implementation work. Each will become an ADR when its forcing function arrives.

| Decision | Deferred until |
|---|---|
| CloudEvents envelope for Kafka events | The first Money event is published to Kafka |
| Aggregate boundaries (Account, TransactionStream, etc.) | The first Money domain feature is implemented |
| Wolverine outbox conventions (topic naming, partition keys) | The first cross-domain event is wired |
| Projection strategy (inline vs async, snapshots, rebuild) | UI work begins that consumes Money read models |
| Cron jobs (Quartz vs alternatives, job list, failure semantics) | A recurring or scheduled task is actually needed |

## Numbering

ADRs are numbered in acceptance order (the order in which they were marked Accepted). Numbers are **monotonic and never reused**. Per the per-service ADR convention, Money's numbering is independent of other services — each service's ADR folder starts at 0001.

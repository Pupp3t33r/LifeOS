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
| [0005](./0005-aggregate-boundaries.md) | Aggregate boundaries | 2026-06-14 |
| [0006](./0006-budget-aggregate.md) | Budget aggregate (light monthly category targets) | 2026-06-15 |
| [0007](./0007-monthly-review-and-projection.md) | MonthlyReview aggregate, Month projection, month-close flow | 2026-06-15 |
| [0008](./0008-multi-currency-and-fx.md) | Multi-currency Money value object and FX rate service (supersedes part of 0005) | 2026-06-15 |
| [0009](./0009-savings-accounts-and-month-close.md) | Savings accounts as the only account type | 2026-06-15 |
| [0010](./0010-asset-aggregate.md) | Asset aggregate (financial fields only) | 2026-06-15 |

## Superseded

| # | Title | Superseded by | Notes |
|---|---|---|---|
| 0005 §Multi-currency | Per-account `Dictionary<string, decimal>` balances; FX out of scope for v1 | [0008](./0008-multi-currency-and-fx.md) | Only the Multi-currency subsection is superseded. The rest of ADR-0005 stands. |

## Deferred decisions

The following decisions have been identified but **intentionally deferred** until they can be grounded in real implementation work. Each will become an ADR when its forcing function arrives.

| Decision | Deferred until |
|---|---|
| CloudEvents envelope for Kafka events | The first Money event is published to Kafka |
| Wolverine outbox conventions (topic naming, partition keys) | The first cross-domain event is wired |
| Projection strategy (inline vs async, snapshots, rebuild) | The first projection lands (MonthProjection per ADR-0007 is the forcing function) |
| Tag storage (Marten documents vs side table vs projection-only) | The first tag-consuming feature is implemented (budgets by tag per ADR-0006, transaction tag filtering) |
| Transfer aggregate (first-class vs paired transactions) | Real-world transfer volume justifies a dedicated aggregate; for v1 paired transactions with `TransferId` suffice (ADR-0009) |

## Numbering

ADRs are numbered in acceptance order (the order in which they were marked Accepted). Numbers are **monotonic and never reused**. Per the per-service ADR convention, Money's numbering is independent of other services — each service's ADR folder starts at 0001.

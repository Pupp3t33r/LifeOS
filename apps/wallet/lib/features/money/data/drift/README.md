# features/money/data/drift

drift (SQLite) tables and DAOs holding **cached read models** and the
`pending_operations` outbox. Cached projections only — never an event log.
Generated with `build_runner` (`drift_dev`).

## Tables

The tables live in `lib/app/data/` (app-wide, opened once by `AppDatabase`):

- **`pending_operations`** (`pending_operations.dart`) — the outbox: queued HTTP
  mutations with idempotency keys (Money ADR-0003) and status. Drained by
  `app/sync/OutboxDrainer`.
- **`cached_flow_entries`** (`cached_flow_entries.dart`) — the period flow-ledger
  read-model (Money ADR-0016): one row per server-confirmed entry, lines as a JSON
  blob, indexed by `(year, month)`. Mirrors `GET /months/{year}/{month}`.
- **`cached_period_meta`** (`cached_period_meta.dart`) — per-period "last synced"
  timestamp, so even an empty period records that it was checked.

The read side lives in `features/money/data/period_flows_repository.dart` (fetch /
watch / refresh) and `features/money/application/period_flows_providers.dart`
(reactive merge + revalidation).

## Caching strategy — stale-while-revalidate

The cockpit renders the cache **immediately** and revalidates in the background:
fetch on screen open and on every outbox change, rewrite the period's rows in one
transaction, and swallow network errors so offline reads stand.

**Optimistic writes do NOT touch the cache.** The cache only ever holds
server-confirmed truth. A just-added (or offline) entry is shown by decoding the
pending `record_flow` op straight from the outbox and merging it into the view as a
"Syncing" row, deduped by `entryId` once the confirmed row lands. This *refines* the
"apply optimistically to cached read models" line in `apps/wallet/AGENTS.md` — we
overlay from the outbox rather than writing provisional rows into the cache, so the
cache never holds unconfirmed state to reconcile.

## Retention — keep everything, no eviction (deliberate)

Every period ever fetched stays cached for offline history. Accepted trade-off, not
a leak: entries are a few hundred bytes each, and past periods are immutable once
closed (Money ADR-0007/0023). Revisit only if multi-year accounts make the table
large enough to warrant a rolling window.

## Known limitations / potential issues

- **Eager revalidation (chattiness).** The current period is refetched on *every*
  screen build, plus on every outbox change, with no TTL. Fine for a solo user
  hitting their own gateway; add a short throttle (skip if refreshed < N seconds ago)
  if it proves noisy.
- **Sync flicker.** A just-synced entry can blink: when its outbox op flips `synced`
  it leaves the optimistic overlay a beat *before* the background refresh lands the
  confirmed cache row. Sub-second for a solo user. Closing it fully needs the drainer
  to signal "synced id → refresh that period", which couples the drainer to this
  feature — deferred.
- **Freshness line doesn't tick.** The header's "Updated …" relative time is computed
  at build, not on a timer; it only re-renders when the view rebuilds (which, given
  eager revalidation, is often). A long-idle screen could show a stale "Updated 2m
  ago". A periodic rebuild would fix it if it matters.
- **Flow ledger only — not `MonthProjection`.** There is no projected/target/actual
  savings here (Money ADR-0007): those need recurring/installments/planned/budgets/
  review. The richer cockpit returns when the composed `MonthProjection` is built.
- **Display-only money math.** Cached amounts round-trip through `double`
  (`Money.amount` is `num`); the decimal-safe representation lands with the OpenAPI
  dart-dio client (Phase 5). Do not build money math on the cache.

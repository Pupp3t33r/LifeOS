# app/sync

Shell-level sync orchestration.

`outbox_drainer.dart` — `OutboxDrainer` replays the `pending_operations` outbox
(see `lib/app/data/`) to the Money API, retiring each row by outcome (2xx/409 →
synced, other 4xx → failed, transient/offline → left pending). Replays
`method`/`path`/`payload` verbatim; no client-side validation or event sourcing —
Money is the source of truth (see apps/wallet/AGENTS.md).

`outbox_sync.dart` — `outboxSyncProvider` drains on launch/sign-in (gated on
auth). Watched by the app root so it lives for the session. The other trigger is
the feature's, right after an `enqueue`: `ref.read(outboxDrainerProvider).drain()`.

The "fetch & cache" half (refreshing cached read models) now exists for the period
flow ledger — stale-while-revalidate plus an outbox-decoded optimistic overlay. It
lives in the feature layer (`features/money/data/period_flows_repository.dart` +
`features/money/application/period_flows_providers.dart`), not here; see
`features/money/data/drift/README.md` for the strategy and its known limitations.

One coupling is deliberately *not* wired: a successful drain does **not** notify the
cache to refresh the affected period, so a just-synced entry can briefly flicker (the
drift README's "Sync flicker" note). Closing it would mean the drainer signalling the
money feature on sync — deferred.

Deferred: connectivity-driven auto-drain (`connectivity_plus`).

Future direction (not built): turn `pending_operations` from a drain-and-forget
queue into a **durable operations log** — retain synced rows too and show only
pending by default, giving an audit/history of every change. This pairs with the
"always queue, even when online" path. It's an input to the pending offline-first
ADR; see `apps/wallet/PLAN.md` §12 "Offline-first". The current drainer still retires
synced rows, so adopting the log means a schema/retention change here.

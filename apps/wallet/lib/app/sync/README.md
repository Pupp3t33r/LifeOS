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

Deferred: connectivity-driven auto-drain (`connectivity_plus`) and refreshing
cached read models (the "fetch & cache" half).

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

Deferred (design not started): **failed-op error handling.** A `failed` row (a
server-rejected 4xx) is currently just dropped from figures and left as a silent
diagnostic — there is no resolution surface, no retry / edit-and-resend / discard,
and no per-entity error taxonomy. This is intentionally held until the full set of
syncable entities and their error types is known (it's one conversation, not a
per-feature bolt-on). New op kinds must record their rejection modes as they land.
See `apps/wallet/PLAN.md` §12 "Offline-first" for the tracked item.

Ordering note (for a possible future). The drain is single, app-lifetime, and
strictly **oldest-first**, so an op that depends on an earlier one drains after it
for free — e.g. *create a payment plan offline, then immediately mark its first
payment paid*: the `create_recurring` op is enqueued first, so it replays before
the dependent `confirm_occurrence` (which would otherwise 404). This is the
ordering that offline occurrence projection — a deferred, likely-never idea
(`PLAN.md` §12 "Offline-first") — would rely on. The one latent gap is same-instant
enqueues tying on `createdAt` (stored as unix seconds, no tiebreaker) — a monotonic
`seq`/rowid tiebreak would close it, deferred until that projection is real. The
current sync-after-write behaviour has no cross-op dependency, so order within a
second doesn't matter.

Future direction (not built): turn `pending_operations` from a drain-and-forget
queue into a **durable operations log** — retain synced rows too and show only
pending by default, giving an audit/history of every change. This pairs with the
"always queue, even when online" path. It's an input to the pending offline-first
ADR; see `apps/wallet/PLAN.md` §12 "Offline-first". The current drainer still retires
synced rows, so adopting the log means a schema/retention change here.

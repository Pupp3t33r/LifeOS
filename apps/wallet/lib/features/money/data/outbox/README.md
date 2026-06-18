# features/money/data/outbox

Outbox logic: enqueue mutations with idempotency keys (Money ADR-0003), track
status (`pending` / `syncing` / `failed` / `synced`), and replay on reconnect.
Drained by `app/sync`. Optimistic updates to cached read models live here.

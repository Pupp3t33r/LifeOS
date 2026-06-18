# app/sync

Shell-level sync orchestration: drains the `pending_operations` outbox to the
Money API on reconnect and refreshes cached read models. No client-side event
sourcing — Money is the source of truth (see apps/wallet/AGENTS.md).

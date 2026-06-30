# features/money/data/outbox

The generic, operation-agnostic outbox now lives at **`lib/app/data/`**
(shell-level: `PendingOperations` table, `OutboxRepository`), because it's
drained by `app/sync` and isn't money-specific.

This directory is reserved for **money-specific enqueue helpers** — code that
builds a concrete operation (e.g. a `record_transaction` op: client-assigned
`transactionId`, signed amount, currency, description, `occurredAt` →
`POST /accounts/{id}/transactions`) and hands it to `OutboxRepository.enqueue`,
then triggers a drain. Added when the add-payment surface lands.

/// Lifecycle of a queued outbox operation.
///
/// A row starts [pending], is claimed as [syncing] while the drainer replays it,
/// then becomes [synced] on success or [failed] on a non-retryable server
/// rejection (a 4xx the user must resolve). Transient or offline errors leave
/// the row [pending] for the next drain — they are not failures.
enum OperationStatus { pending, syncing, synced, failed }

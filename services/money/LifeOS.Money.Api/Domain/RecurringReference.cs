namespace LifeOS.Money.Api.Domain;

/// A soft back-reference from an AccountingPeriod entry to the recurring occurrence it
/// confirms or skips (ADR-0017). The recurring aggregate stores no per-occurrence
/// state; instead confirmations (<c>FlowRecorded</c>) and skips (<c>OccurrenceSkipped</c>)
/// on the period carry this reference, and the projection joins computed/listed
/// occurrences against it to derive each occurrence's status.
///
/// <see cref="OccurrenceRef"/> is the occurrence's stable key: the schedule
/// <c>LineId</c> for a Materialized occurrence, or the due date (<c>yyyy-MM-dd</c>)
/// for a Live one — the same value surfaced as an occurrence's reference on read.
public sealed record RecurringReference(Guid RecurringId, string OccurrenceRef)
{
    /// The per-period idempotency/lookup key ("already resolved this occurrence?").
    public string ToKey() => $"{RecurringId}:{OccurrenceRef}";
}

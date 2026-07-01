namespace LifeOS.Money.Api.Projections;

/// Read-model row for a skipped recurring occurrence (ADR-0017). Keyed by the
/// occurrence's global key (<c>{RecurringId}:{OccurrenceRef}</c>) — an occurrence maps
/// to exactly one period, so the key is unique. The occurrence-status read queries
/// these by owner + recurring id to mark occurrences skipped.
public sealed class SkippedOccurrenceRecord
{
    public string Id { get; set; } = string.Empty;
    public string OwnerId { get; set; } = string.Empty;
    public Guid RecurringId { get; set; }
    public string OccurrenceRef { get; set; } = string.Empty;
    public int Year { get; set; }
    public int Month { get; set; }
    public DateTimeOffset RecordedAt { get; set; }
}

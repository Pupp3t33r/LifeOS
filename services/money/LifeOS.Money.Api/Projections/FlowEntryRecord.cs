using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Domain.Events;

namespace LifeOS.Money.Api.Projections;

/// Read-model row for one recorded flow entry (ADR-0016/0019): the per-entry shape
/// the Wallet's current-period cockpit lists. [Total] is the entry's Σ of signed
/// line amounts (ADR-0026), in the entry's single currency (ADR-0019). Keyed by the
/// client-assigned [Id] (= EntryId), so a duplicate replay never forks the row.
public sealed class FlowEntryRecord
{
    public Guid Id { get; set; }
    public Guid PeriodId { get; set; }
    public string OwnerId { get; set; } = string.Empty;
    public int Year { get; set; }
    public int Month { get; set; }
    public FlowDirection Direction { get; set; }
    public IReadOnlyList<Line> Lines { get; set; } = [];
    public CurrencyAmount Total { get; set; } = new(0, string.Empty);
    public DateTimeOffset OccurredAt { get; set; }
    public DateTimeOffset RecordedAt { get; set; }
    public string? Description { get; set; }

    /// Set when this entry confirmed a recurring occurrence (ADR-0017); the join key
    /// the occurrence-status read uses to mark that occurrence paid. Null for ad-hoc.
    public RecurringReference? Recurring { get; set; }

    /// Set when this entry paid a planned purchase (ADR-0018); the join key the
    /// planned-purchase read uses to mark that entry paid. Null for ad-hoc.
    public Guid? PlannedEntryId { get; set; }
}

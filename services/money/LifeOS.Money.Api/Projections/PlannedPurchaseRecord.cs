using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Domain.Events;

namespace LifeOS.Money.Api.Projections;

/// Read-model row for one live planned purchase (ADR-0018): the per-entry shape the
/// Wallet cockpit lists under "Upcoming/Planned". [Total] is the Σ of signed line
/// amounts (ADR-0026), negative for spending, in the entry's single currency
/// (ADR-0019). Keyed by the client-assigned [Id] (= EntryId).
///
/// Cancelling deletes the row; being <b>paid</b> is derived at read by joining a
/// confirming <c>FlowRecorded</c> whose <c>PlannedEntryId</c> equals this [Id] — the
/// row itself is not mutated on pay, mirroring how occurrence status is a join.
public sealed class PlannedPurchaseRecord
{
    public Guid Id { get; set; }
    public Guid PeriodId { get; set; }
    public string OwnerId { get; set; } = string.Empty;
    public int Year { get; set; }
    public int Month { get; set; }
    public IReadOnlyList<Line> Lines { get; set; } = [];
    public CurrencyAmount Total { get; set; } = new(0, string.Empty);
    public DateTimeOffset AddedAt { get; set; }
    public string? Description { get; set; }

    /// Optional "buy by" date (ADR-0034); null when the period was chosen directly.
    public DateOnly? Deadline { get; set; }

    /// Set only for a carry-make-up entry (ADR-0020); null otherwise.
    public PlannedPurchaseOrigin? Origin { get; set; }
}

using LifeOS.Money.Api.Domain.Events;

namespace LifeOS.Money.Api.Domain;

/// The per-month stream (ADR-0016): everyday flow actuals for one owner's period,
/// keyed by a deterministic id from owner+year+month (see <see cref="PeriodStream"/>).
///
/// v1 holds only the flow ledger and its idempotency set. The lifecycle
/// (open / target / close — ADR-0007/0023) and the other flow events
/// (<c>FlowReverted</c>, <c>UnaccountedFlowRecorded</c> — ADR-0026) join as those
/// features land.
public sealed class AccountingPeriod {
    public Guid Id { get; set; }
    public string OwnerId { get; set; } = string.Empty;
    public int Year { get; set; }
    public int Month { get; set; }
    public HashSet<Guid> RecordedEntryIds { get; set; } = new();

    public FlowRecorded RecordFlow(
        Guid periodId,
        string ownerId,
        int year,
        int month,
        Guid entryId,
        FlowDirection direction,
        IReadOnlyList<Line> lines,
        DateTimeOffset occurredAt,
        DateTimeOffset recordedAt,
        string? description) {
        if (lines.Count == 0) {
            throw new ArgumentException("A flow entry needs at least one line.", nameof(lines));
        }

        if (lines.Any(x => x.Amount.Amount == 0)) {
            throw new ArgumentException("Line amounts must be non-zero.", nameof(lines));
        }

        var currency = lines[0].Amount.Currency;
        if (lines.Any(x => x.Amount.Currency != currency)) {
            throw new InvalidOperationException("All lines in a flow entry share one currency (ADR-0019).");
        }

        if (RecordedEntryIds.Contains(entryId)) {
            throw new DuplicateFlowException(entryId);
        }

        return new FlowRecorded(
            periodId, ownerId, year, month, entryId, direction, lines, occurredAt, recordedAt, description);
    }

    public void Apply(FlowRecorded @event) {
        Id = @event.PeriodId;
        OwnerId = @event.OwnerId;
        Year = @event.Year;
        Month = @event.Month;
        RecordedEntryIds.Add(@event.EntryId);
    }
}

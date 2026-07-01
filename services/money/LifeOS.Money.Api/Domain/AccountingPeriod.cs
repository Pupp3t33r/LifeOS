using LifeOS.Money.Api.Domain.Events;

namespace LifeOS.Money.Api.Domain;

/// The per-month stream (ADR-0016): everyday flow actuals for one owner's period,
/// keyed by a deterministic id from owner+year+month (see <see cref="PeriodStream"/>).
///
/// It also tracks which recurring occurrences have been <b>resolved</b> in this period
/// — confirmed (a <c>FlowRecorded</c> carrying a back-ref) or skipped
/// (<c>OccurrenceSkipped</c>) — for ADR-0017's within-period idempotency ("already
/// confirmed/skipped this occurrence?"): an occurrence maps to exactly one period by
/// its date, so no double-confirm is a local check.
///
/// v1 holds the flow ledger, its idempotency set, and occurrence resolution. The
/// lifecycle (open / target / close — ADR-0007/0023) and the other flow events
/// (<c>FlowReverted</c>, <c>UnaccountedFlowRecorded</c> — ADR-0026) join as those
/// features land.
public sealed class AccountingPeriod {
    public Guid Id { get; set; }
    public string OwnerId { get; set; } = string.Empty;
    public int Year { get; set; }
    public int Month { get; set; }
    public HashSet<Guid> RecordedEntryIds { get; set; } = new();

    /// Keys (<c>{RecurringId}:{OccurrenceRef}</c>) of occurrences confirmed or skipped
    /// in this period. An occurrence may be resolved once (ADR-0017).
    public HashSet<string> ResolvedOccurrences { get; set; } = new();

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
        string? description,
        RecurringReference? recurring = null) {
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

        if (recurring is not null && ResolvedOccurrences.Contains(recurring.ToKey())) {
            throw new DuplicateOccurrenceException(recurring);
        }

        return new FlowRecorded(
            periodId, ownerId, year, month, entryId, direction, lines, occurredAt, recordedAt, description, recurring);
    }

    public OccurrenceSkipped SkipOccurrence(
        Guid periodId,
        string ownerId,
        int year,
        int month,
        RecurringReference occurrence,
        DateTimeOffset recordedAt) {
        if (ResolvedOccurrences.Contains(occurrence.ToKey())) {
            throw new DuplicateOccurrenceException(occurrence);
        }

        return new OccurrenceSkipped(periodId, ownerId, year, month, occurrence, recordedAt);
    }

    public bool IsOccurrenceResolved(RecurringReference occurrence) =>
        ResolvedOccurrences.Contains(occurrence.ToKey());

    public void Apply(FlowRecorded @event) {
        Id = @event.PeriodId;
        OwnerId = @event.OwnerId;
        Year = @event.Year;
        Month = @event.Month;
        RecordedEntryIds.Add(@event.EntryId);
        if (@event.Recurring is not null) {
            ResolvedOccurrences.Add(@event.Recurring.ToKey());
        }
    }

    public void Apply(OccurrenceSkipped @event) {
        Id = @event.PeriodId;
        OwnerId = @event.OwnerId;
        Year = @event.Year;
        Month = @event.Month;
        ResolvedOccurrences.Add(@event.Occurrence.ToKey());
    }
}

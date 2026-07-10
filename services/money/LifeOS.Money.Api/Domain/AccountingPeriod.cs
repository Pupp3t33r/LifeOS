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
/// It carries planned purchases too (ADR-0018): line-itemed intentions to buy this
/// month, added/edited/cancelled here and turned into an actual by a
/// <c>FlowRecorded</c> back-referencing the entry (<c>PlannedEntryId</c>). Their
/// live/cancelled/paid id-sets give edit/cancel/pay their within-period guards, one
/// planned purchase resolving to at most one paying flow.
///
/// v1 holds the flow ledger, its idempotency set, occurrence resolution, and planned
/// purchases. The lifecycle (open / target / close — ADR-0007/0023) and the other flow
/// events (<c>FlowReverted</c>, <c>UnaccountedFlowRecorded</c> — ADR-0026) join as
/// those features land.
public sealed class AccountingPeriod {
    public Guid Id { get; set; }
    public string OwnerId { get; set; } = string.Empty;
    public int Year { get; set; }
    public int Month { get; set; }
    public HashSet<Guid> RecordedEntryIds { get; set; } = new();

    /// Keys (<c>{RecurringId}:{OccurrenceRef}</c>) of occurrences confirmed or skipped
    /// in this period. An occurrence may be resolved once (ADR-0017).
    public HashSet<string> ResolvedOccurrences { get; set; } = new();

    /// Planned-purchase entry ids ever added to this period (ADR-0018) — the add
    /// idempotency set and the existence check for edit/cancel/pay.
    public HashSet<Guid> PlannedEntryIds { get; set; } = new();

    /// Planned-purchase entry ids cancelled in this period (terminal).
    public HashSet<Guid> CancelledPlannedEntryIds { get; set; } = new();

    /// Planned-purchase entry ids paid — a confirming <c>FlowRecorded</c> carried the
    /// id as its <c>PlannedEntryId</c>. A planned purchase pays once.
    public HashSet<Guid> PaidPlannedEntryIds { get; set; } = new();

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
        RecurringReference? recurring = null,
        Guid? plannedEntryId = null) {
        ValidateLines(lines);

        if (recurring is not null && plannedEntryId is not null) {
            throw new InvalidOperationException(
                "A flow confirms either a recurring occurrence or a planned purchase, not both.");
        }

        if (RecordedEntryIds.Contains(entryId)) {
            throw new DuplicateFlowException(entryId);
        }

        if (recurring is not null && ResolvedOccurrences.Contains(recurring.ToKey())) {
            throw new DuplicateOccurrenceException(recurring);
        }

        if (plannedEntryId is Guid planned) {
            RequireLivePlannedPurchase(planned);
        }

        return new FlowRecorded(
            periodId, ownerId, year, month, entryId, direction, lines, occurredAt, recordedAt,
            description, recurring, plannedEntryId);
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

    /// Add a line-itemed planned purchase to this period (ADR-0018). Idempotent on
    /// [entryId] — a re-add is a <see cref="DuplicatePlannedPurchaseException"/> (409,
    /// treated by the outbox as already-applied).
    public PlannedPurchaseAdded AddPlannedPurchase(
        Guid periodId,
        string ownerId,
        int year,
        int month,
        Guid entryId,
        IReadOnlyList<Line> lines,
        DateTimeOffset addedAt,
        string? description,
        PlannedPurchaseOrigin? origin = null,
        DateOnly? deadline = null) {
        ValidateLines(lines);
        if (PlannedEntryIds.Contains(entryId)) {
            throw new DuplicatePlannedPurchaseException(entryId);
        }

        return new PlannedPurchaseAdded(
            periodId, ownerId, year, month, entryId, lines, addedAt, description, origin, deadline);
    }

    /// Edit an unpaid, uncancelled planned purchase in place (ADR-0018).
    public PlannedPurchaseEdited EditPlannedPurchase(
        Guid periodId,
        string ownerId,
        int year,
        int month,
        Guid entryId,
        IReadOnlyList<Line> lines,
        DateTimeOffset editedAt,
        string? description,
        DateOnly? deadline = null) {
        ValidateLines(lines);
        RequireLivePlannedPurchase(entryId);
        return new PlannedPurchaseEdited(
            periodId, ownerId, year, month, entryId, lines, editedAt, description, deadline);
    }

    /// Cancel a planned purchase (ADR-0018) — terminal for that entry.
    public PlannedPurchaseCancelled CancelPlannedPurchase(
        Guid periodId,
        string ownerId,
        int year,
        int month,
        Guid entryId,
        DateTimeOffset cancelledAt) {
        RequireLivePlannedPurchase(entryId);
        return new PlannedPurchaseCancelled(periodId, ownerId, year, month, entryId, cancelledAt);
    }

    public bool IsPlannedPurchaseLive(Guid entryId) =>
        PlannedEntryIds.Contains(entryId)
        && !CancelledPlannedEntryIds.Contains(entryId)
        && !PaidPlannedEntryIds.Contains(entryId);

    public void Apply(FlowRecorded @event) {
        Id = @event.PeriodId;
        OwnerId = @event.OwnerId;
        Year = @event.Year;
        Month = @event.Month;
        RecordedEntryIds.Add(@event.EntryId);
        if (@event.Recurring is not null) {
            ResolvedOccurrences.Add(@event.Recurring.ToKey());
        }

        if (@event.PlannedEntryId is Guid planned) {
            PaidPlannedEntryIds.Add(planned);
        }
    }

    public void Apply(OccurrenceSkipped @event) {
        Id = @event.PeriodId;
        OwnerId = @event.OwnerId;
        Year = @event.Year;
        Month = @event.Month;
        ResolvedOccurrences.Add(@event.Occurrence.ToKey());
    }

    public void Apply(PlannedPurchaseAdded @event) {
        Id = @event.PeriodId;
        OwnerId = @event.OwnerId;
        Year = @event.Year;
        Month = @event.Month;
        PlannedEntryIds.Add(@event.EntryId);
    }

    public void Apply(PlannedPurchaseCancelled @event) {
        Id = @event.PeriodId;
        OwnerId = @event.OwnerId;
        Year = @event.Year;
        Month = @event.Month;
        CancelledPlannedEntryIds.Add(@event.EntryId);
    }

    private void RequireLivePlannedPurchase(Guid entryId) {
        if (!PlannedEntryIds.Contains(entryId)) {
            throw new PlannedPurchaseNotFoundException(entryId);
        }

        if (CancelledPlannedEntryIds.Contains(entryId)) {
            throw new PlannedPurchaseConflictException(entryId, "it was cancelled");
        }

        if (PaidPlannedEntryIds.Contains(entryId)) {
            throw new PlannedPurchaseConflictException(entryId, "it was already paid");
        }
    }

    private static void ValidateLines(IReadOnlyList<Line> lines) {
        if (lines.Count == 0) {
            throw new ArgumentException("An entry needs at least one line.", nameof(lines));
        }

        if (lines.Any(x => x.Amount.Amount == 0)) {
            throw new ArgumentException("Line amounts must be non-zero.", nameof(lines));
        }

        var currency = lines[0].Amount.Currency;
        if (lines.Any(x => x.Amount.Currency != currency)) {
            throw new InvalidOperationException("All lines in an entry share one currency (ADR-0019).");
        }
    }
}

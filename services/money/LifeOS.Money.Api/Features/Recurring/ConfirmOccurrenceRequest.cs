namespace LifeOS.Money.Api.Features.Recurring;

/// Confirm a recurring occurrence as paid (ADR-0017). <see cref="EntryId"/> is the
/// client-assigned id of the resulting flow (idempotency, ADR-0003).
/// <see cref="OccurredAt"/> is the actual payment date (may differ from the due date);
/// the entry lands in the period that date maps to (ADR-0016). <see cref="Lines"/> is
/// an optional override — omit to use the occurrence's expected lines. For a Live
/// occurrence it is a full breakdown override; for a payment plan it may carry at most
/// one line, an amount-only adjustment of what was actually paid (ADR-0029), never an
/// itemisation.
public sealed record ConfirmOccurrenceRequest(
    Guid EntryId,
    string OccurrenceRef,
    DateTimeOffset OccurredAt,
    IReadOnlyList<RecurringLineRequest>? Lines,
    string? Description);

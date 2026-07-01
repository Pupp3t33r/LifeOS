using LifeOS.Money.Api.Domain;

namespace LifeOS.Money.Api.Features.Recurring;

/// The flow recorded by confirming an occurrence: which period it landed in, its
/// signed total, and the timestamps. The occurrence is now <c>paid</c> in that period.
public sealed record ConfirmOccurrenceResponse(
    Guid PeriodId,
    Guid EntryId,
    string OccurrenceRef,
    CurrencyAmount Total,
    DateTimeOffset OccurredAt,
    DateTimeOffset RecordedAt);

namespace LifeOS.Money.Api.Features.Recurring;

/// The result of skipping an occurrence: the period it was recorded skipped in.
public sealed record SkipOccurrenceResponse(
    Guid PeriodId,
    string OccurrenceRef,
    int Year,
    int Month,
    DateTimeOffset RecordedAt);

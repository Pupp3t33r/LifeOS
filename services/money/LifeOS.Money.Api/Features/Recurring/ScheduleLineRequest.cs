namespace LifeOS.Money.Api.Features.Recurring;

/// A Materialized schedule line in a request: client-assigned <see cref="LineId"/>
/// (the stable occurrence reference), a due date, and its line-item breakdown.
public sealed record ScheduleLineRequest(
    Guid LineId,
    DateOnly DueDate,
    IReadOnlyList<RecurringLineRequest> Lines);

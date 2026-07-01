using LifeOS.Money.Api.Domain;

namespace LifeOS.Money.Api.Features.Recurring;

/// A Materialized schedule line in a response: its lines (signed) plus the signed
/// <see cref="Total"/> for convenience.
public sealed record ScheduleLineResponse(
    Guid LineId,
    DateOnly DueDate,
    IReadOnlyList<Line> Lines,
    CurrencyAmount Total);

namespace LifeOS.Money.Api.Features.Recurring;

/// A Materialized scheduled payment in a request (ADR-0028): client-assigned
/// <see cref="LineId"/> (the stable occurrence reference), a due date, and a bare
/// <see cref="Amount"/> — a positive magnitude; the plan's direction sets the sign.
/// The plan's line-item contents live on the request's <c>Items</c>, not here.
public sealed record ScheduleLineRequest(Guid LineId, DateOnly DueDate, decimal Amount);

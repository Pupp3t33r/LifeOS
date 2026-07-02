using LifeOS.Money.Api.Domain;

namespace LifeOS.Money.Api.Features.Recurring;

/// A Materialized scheduled payment in a response (ADR-0028): a due date and the signed
/// <see cref="Amount"/>. The plan's contents are on the response's <c>Items</c>; the
/// slice a given payment covers is available per occurrence from get-occurrences.
public sealed record ScheduleLineResponse(
    Guid LineId,
    DateOnly DueDate,
    CurrencyAmount Amount);

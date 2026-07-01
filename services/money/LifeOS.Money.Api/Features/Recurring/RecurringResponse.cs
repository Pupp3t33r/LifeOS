using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Domain.Recurring;

namespace LifeOS.Money.Api.Features.Recurring;

/// A recurring payment's full definition. For Live, <see cref="Rule"/> +
/// <see cref="EstimateLines"/> + <see cref="EstimatedAmount"/> (Σ estimate) are set
/// and <see cref="ScheduleLines"/> is empty; for Materialized it is the reverse.
public sealed record RecurringResponse(
    Guid Id,
    string OwnerId,
    string Name,
    string Direction,
    string Currency,
    Guid? CategoryId,
    Guid? AccountId,
    string Mode,
    RecurrenceRule? Rule,
    IReadOnlyList<Line> EstimateLines,
    CurrencyAmount? EstimatedAmount,
    IReadOnlyList<ScheduleLineResponse> ScheduleLines,
    string Status,
    DateTimeOffset CreatedAt);

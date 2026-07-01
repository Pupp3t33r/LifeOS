using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Domain.Recurring;

namespace LifeOS.Money.Api.Domain.Events;

/// A recurring payment/income was defined (ADR-0017). Carries the full definition:
/// header + the schedule in one of two modes. For <see cref="ScheduleMode.Live"/>,
/// <see cref="Rule"/> and <see cref="EstimateLines"/> (the per-occurrence breakdown)
/// are set and <see cref="ScheduleLines"/> is empty; for
/// <see cref="ScheduleMode.Materialized"/> it is the reverse.
public sealed record RecurringPaymentCreated(
    Guid RecurringId,
    string OwnerId,
    string Name,
    FlowDirection Direction,
    string Currency,
    Guid? CategoryId,
    Guid? AccountId,
    ScheduleMode Mode,
    RecurrenceRule? Rule,
    IReadOnlyList<Line> EstimateLines,
    IReadOnlyList<ScheduleLine> ScheduleLines,
    DateTimeOffset CreatedAt);

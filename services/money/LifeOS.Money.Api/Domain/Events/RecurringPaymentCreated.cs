using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Domain.Recurring;

namespace LifeOS.Money.Api.Domain.Events;

/// A recurring payment/income was defined (ADR-0017; contents-at-root per ADR-0028,
/// priceless plan items per ADR-0029). Carries the full definition: header + the
/// schedule in one of two modes. For <see cref="ScheduleMode.Live"/>, <see cref="Rule"/>
/// and <see cref="EstimateLines"/> (the per-occurrence breakdown) are set and
/// <see cref="Items"/>/<see cref="ScheduleLines"/> are empty; for
/// <see cref="ScheduleMode.Materialized"/> it is the reverse — <see cref="Items"/> holds
/// the plan's priceless line-item contents once, and <see cref="ScheduleLines"/> are the
/// bare-money payments (the plan total is Σ payments; there is no items↔payments balance).
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
    IReadOnlyList<PlanItem> Items,
    IReadOnlyList<ScheduleLine> ScheduleLines,
    DateTimeOffset CreatedAt);

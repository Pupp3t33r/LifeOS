using LifeOS.Money.Api.Domain.Recurring;

namespace LifeOS.Money.Api.Features.Recurring;

/// Create a recurring payment/income (ADR-0017). <see cref="RecurringId"/> is
/// client-assigned (idempotency, ADR-0003). For <c>mode: "live"</c> supply
/// <see cref="Rule"/> + <see cref="EstimateLines"/>; for <c>mode: "materialized"</c>
/// supply <see cref="ScheduleLines"/>. The rule is a `kind`-discriminated union
/// deserialized polymorphically.
public sealed record CreateRecurringRequest(
    Guid RecurringId,
    string Name,
    string Direction,
    string Currency,
    Guid? CategoryId,
    Guid? AccountId,
    string Mode,
    RecurrenceRule? Rule,
    IReadOnlyList<RecurringLineRequest>? EstimateLines,
    IReadOnlyList<ScheduleLineRequest>? ScheduleLines);

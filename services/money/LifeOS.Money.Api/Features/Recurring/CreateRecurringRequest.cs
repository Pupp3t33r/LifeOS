using LifeOS.Money.Api.Domain.Recurring;

namespace LifeOS.Money.Api.Features.Recurring;

/// Create a recurring payment/income (ADR-0017; contents-at-root per ADR-0028, priceless
/// plan items per ADR-0029). <see cref="RecurringId"/> is client-assigned (idempotency,
/// ADR-0003). For <c>mode: "live"</c> supply <see cref="Rule"/> + <see cref="EstimateLines"/>;
/// for <c>mode: "materialized"</c> supply the plan's <see cref="Items"/> (priceless
/// line-item contents) and <see cref="ScheduleLines"/> (bare-money payments) — the plan
/// total is Σ payments; items carry no cost and need not balance the payments. The rule
/// is a `kind`-discriminated union deserialized polymorphically.
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
    IReadOnlyList<PlanItemRequest>? Items,
    IReadOnlyList<ScheduleLineRequest>? ScheduleLines);

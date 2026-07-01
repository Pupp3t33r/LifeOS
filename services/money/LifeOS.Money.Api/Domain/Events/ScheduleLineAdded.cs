using LifeOS.Money.Api.Domain.Recurring;

namespace LifeOS.Money.Api.Domain.Events;

/// A line was added to a Materialized schedule (ADR-0017).
public sealed record ScheduleLineAdded(Guid RecurringId, ScheduleLine Line);

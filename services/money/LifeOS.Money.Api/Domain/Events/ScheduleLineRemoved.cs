namespace LifeOS.Money.Api.Domain.Events;

/// An unconfirmed Materialized schedule line was removed (ADR-0017).
public sealed record ScheduleLineRemoved(Guid RecurringId, Guid LineId);

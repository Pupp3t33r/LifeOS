namespace LifeOS.Money.Api.Domain.Recurring;

/// Every <see cref="IntervalDays"/> days from Start (e.g. every 20 days) — the case
/// standard cron cannot express because it resets monthly.
public sealed record DailyRule(DateOnly Start, RecurrenceEnd End, int IntervalDays)
    : RecurrenceRule(Start, End);

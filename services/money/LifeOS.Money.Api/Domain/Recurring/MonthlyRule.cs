namespace LifeOS.Money.Api.Domain.Recurring;

/// On the given <see cref="Days"/> anchors, every <see cref="IntervalMonths"/> months
/// (e.g. the 1st &amp; 15th; the last day; quarterly). Months are counted from Start's
/// month. <see cref="Days"/> is treated as a set.
public sealed record MonthlyRule(
    DateOnly Start,
    RecurrenceEnd End,
    int IntervalMonths,
    IReadOnlyList<MonthDayAnchor> Days)
    : RecurrenceRule(Start, End);

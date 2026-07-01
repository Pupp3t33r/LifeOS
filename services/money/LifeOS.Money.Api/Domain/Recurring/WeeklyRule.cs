namespace LifeOS.Money.Api.Domain.Recurring;

/// On the given <see cref="Weekdays"/>, every <see cref="IntervalWeeks"/> weeks (e.g.
/// every Monday; bi-weekly Friday). Weeks are anchored on the Monday of Start's week,
/// so bi-weekly fires on the same fortnightly cadence as Start. <see cref="Weekdays"/>
/// is treated as a set (order/duplicates ignored by the generator).
public sealed record WeeklyRule(
    DateOnly Start,
    RecurrenceEnd End,
    int IntervalWeeks,
    IReadOnlyList<DayOfWeek> Weekdays)
    : RecurrenceRule(Start, End);

namespace LifeOS.Money.Api.Domain.Recurring;

/// On the given <see cref="Dates"/>, every <see cref="IntervalYears"/> years (e.g. an
/// annual renewal). Years are counted from Start's year. <see cref="Dates"/> is
/// treated as a set.
public sealed record YearlyRule(
    DateOnly Start,
    RecurrenceEnd End,
    int IntervalYears,
    IReadOnlyList<AnnualDate> Dates)
    : RecurrenceRule(Start, End);

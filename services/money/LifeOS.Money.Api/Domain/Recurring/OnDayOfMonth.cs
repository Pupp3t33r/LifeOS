namespace LifeOS.Money.Api.Domain.Recurring;

/// The Nth day of the month (1–31). In months shorter than <see cref="Day"/> the
/// occurrence clamps to the last day (ADR-0013/0017), so day 31 fires on Feb 28/29.
public sealed record OnDayOfMonth(int Day) : MonthDayAnchor;

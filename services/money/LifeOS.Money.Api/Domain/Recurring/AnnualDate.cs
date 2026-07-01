namespace LifeOS.Money.Api.Domain.Recurring;

/// A month-and-day within a year for a <see cref="YearlyRule"/> (ADR-0017).
/// <see cref="Day"/> clamps to the month's length, so (2, 29) fires on Feb 28 in
/// non-leap years.
public sealed record AnnualDate(int Month, int Day);

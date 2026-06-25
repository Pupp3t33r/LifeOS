namespace LifeOS.Money.Api.Domain;

/// The user's configurable monthly period (ADR-0013). A period is identified by
/// `(Year, Month)` — unchanged from ADR-0006/ADR-0007 — but its calendar span is
/// generalized from "calendar month" to a window anchored on the user's
/// configured <c>MonthStartDay</c>.
///
/// Period `(Y, M)` spans the half-open interval <c>[Anchor(Y, M), Anchor(next(Y, M)))</c>,
/// where <c>Anchor(Y, M)</c> is day <c>min(MonthStartDay, daysInMonth(Y, M))</c> — the
/// chosen day, clamped to the month's last day when the month is shorter.
///
/// Periods are <b>start-anchored</b>: named for the calendar month in which they
/// begin. <c>MonthStartDay == 1</c> degenerates to exactly the calendar month, so
/// the default is fully backward-compatible. Clamped anchors stay strictly
/// increasing month-over-month, so periods always tile cleanly — no gaps, no
/// overlaps — at the cost of slightly uneven lengths near short months.
///
/// Consumed by Budget (PLAN §3.6) and MonthProjection (PLAN §3.7) for bucketing.
public static class MonthPeriod
{
    /// The first day of period <paramref name="month"/> in <paramref name="year"/>:
    /// day <c>min(monthStartDay, daysInMonth)</c>.
    public static DateOnly Anchor(int year, int month, int monthStartDay)
    {
        var daysInMonth = DateTime.DaysInMonth(year, month);
        var day = Math.Min(monthStartDay, daysInMonth);
        return new DateOnly(year, month, day);
    }

    /// The half-open span <c>[Start, EndExclusive)</c> of period
    /// <c>(year, month)</c> for the given <paramref name="monthStartDay"/>.
    public static (DateOnly Start, DateOnly EndExclusive) Span(int year, int month, int monthStartDay)
    {
        var start = Anchor(year, month, monthStartDay);
        var (nextYear, nextMonth) = Next(year, month);
        var endExclusive = Anchor(nextYear, nextMonth, monthStartDay);
        return (start, endExclusive);
    }

    /// The period that contains <paramref name="date"/> under
    /// <paramref name="monthStartDay"/> — the bucketing primitive for projections.
    /// A date on or after its calendar month's anchor belongs to that month's
    /// period; an earlier date belongs to the previous calendar month's period.
    public static (int Year, int Month) ContainingPeriod(DateOnly date, int monthStartDay)
    {
        var anchor = Anchor(date.Year, date.Month, monthStartDay);
        return date >= anchor ? (date.Year, date.Month) : Previous(date.Year, date.Month);
    }

    /// The following calendar month, rolling the year at December.
    public static (int Year, int Month) Next(int year, int month) =>
        month == 12 ? (year + 1, 1) : (year, month + 1);

    /// The preceding calendar month, rolling the year at January.
    public static (int Year, int Month) Previous(int year, int month) =>
        month == 1 ? (year - 1, 12) : (year, month - 1);
}

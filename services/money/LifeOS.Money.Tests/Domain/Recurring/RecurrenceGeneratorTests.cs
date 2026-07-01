using LifeOS.Money.Api.Domain.Recurring;
using Xunit;

namespace LifeOS.Money.Tests.Domain.Recurring;

public class RecurrenceGeneratorTests
{
    private static readonly NeverEnds Never = new();

    private static DateOnly D(int y, int m, int d) => new(y, m, d);

    private static List<DateOnly> Window(RecurrenceRule rule, DateOnly start, DateOnly end) =>
        RecurrenceGenerator.InWindow(rule, start, end).ToList();

    [Fact]
    public void Daily_EveryNDays_FromStart_IsAscendingAndPhased()
    {
        // "every 20 days" — the case cron cannot express.
        var rule = new DailyRule(D(2026, 1, 1), Never, 20);

        var dates = Window(rule, D(2026, 1, 1), D(2026, 3, 1));

        Assert.Equal(
            [D(2026, 1, 1), D(2026, 1, 21), D(2026, 2, 10)],
            dates);
    }

    [Fact]
    public void Weekly_BiWeekly_FiresEveryOtherWeekOnWeekday()
    {
        // Start Fri 2026-01-02; bi-weekly Friday.
        var rule = new WeeklyRule(D(2026, 1, 2), Never, 2, [DayOfWeek.Friday]);

        var dates = Window(rule, D(2026, 1, 1), D(2026, 2, 28));

        Assert.Equal(
            [D(2026, 1, 2), D(2026, 1, 16), D(2026, 1, 30), D(2026, 2, 13), D(2026, 2, 27)],
            dates);
    }

    [Fact]
    public void Weekly_MultipleWeekdays_AreOrderedWithinEachWeek()
    {
        // Start Mon 2026-01-05; every week Mon & Wed.
        var rule = new WeeklyRule(D(2026, 1, 5), Never, 1, [DayOfWeek.Wednesday, DayOfWeek.Monday]);

        var dates = Window(rule, D(2026, 1, 5), D(2026, 1, 18));

        Assert.Equal(
            [D(2026, 1, 5), D(2026, 1, 7), D(2026, 1, 12), D(2026, 1, 14)],
            dates);
    }

    [Fact]
    public void Weekly_FirstWeek_ExcludesWeekdaysBeforeStart()
    {
        // Start Wed 2026-01-07; every week Mon & Wed — Monday of that week (Jan 5) is
        // before Start and must be excluded; from the next week both appear.
        var rule = new WeeklyRule(D(2026, 1, 7), Never, 1, [DayOfWeek.Monday, DayOfWeek.Wednesday]);

        var dates = Window(rule, D(2026, 1, 1), D(2026, 1, 14));

        Assert.Equal(
            [D(2026, 1, 7), D(2026, 1, 12), D(2026, 1, 14)],
            dates);
    }

    [Fact]
    public void Monthly_FirstAndFifteenth()
    {
        var rule = new MonthlyRule(D(2026, 1, 1), Never, 1, [new OnDayOfMonth(1), new OnDayOfMonth(15)]);

        var dates = Window(rule, D(2026, 1, 1), D(2026, 2, 20));

        Assert.Equal(
            [D(2026, 1, 1), D(2026, 1, 15), D(2026, 2, 1), D(2026, 2, 15)],
            dates);
    }

    [Fact]
    public void Monthly_DayOfMonth31_ClampsToShortMonths()
    {
        var rule = new MonthlyRule(D(2026, 1, 31), Never, 1, [new OnDayOfMonth(31)]);

        var dates = Window(rule, D(2026, 1, 1), D(2026, 4, 30));

        // Feb clamps to 28, Apr to 30.
        Assert.Equal(
            [D(2026, 1, 31), D(2026, 2, 28), D(2026, 3, 31), D(2026, 4, 30)],
            dates);
    }

    [Fact]
    public void Monthly_LastDay_TracksMonthLength()
    {
        var rule = new MonthlyRule(D(2026, 1, 1), Never, 1, [new LastDayOfMonth()]);

        var dates = Window(rule, D(2026, 1, 1), D(2026, 3, 31));

        Assert.Equal(
            [D(2026, 1, 31), D(2026, 2, 28), D(2026, 3, 31)],
            dates);
    }

    [Fact]
    public void Monthly_Quarterly_SkipsIntervalMonths()
    {
        var rule = new MonthlyRule(D(2026, 1, 10), Never, 3, [new OnDayOfMonth(10)]);

        var dates = Window(rule, D(2026, 1, 1), D(2026, 12, 31));

        Assert.Equal(
            [D(2026, 1, 10), D(2026, 4, 10), D(2026, 7, 10), D(2026, 10, 10)],
            dates);
    }

    [Fact]
    public void Yearly_AnnualDate_ClampsLeapDay()
    {
        var rule = new YearlyRule(D(2024, 2, 29), Never, 1, [new AnnualDate(2, 29)]);

        var dates = Window(rule, D(2024, 1, 1), D(2027, 12, 31));

        // 2024 leap (29), 2025/2026/2027 clamp to Feb 28.
        Assert.Equal(
            [D(2024, 2, 29), D(2025, 2, 28), D(2026, 2, 28), D(2027, 2, 28)],
            dates);
    }

    [Fact]
    public void EndsAfter_CountsFromFirstOccurrence_NotWindow()
    {
        // 3 payments total; the window starts mid-series but the count is global.
        var rule = new MonthlyRule(D(2026, 1, 1), new EndsAfter(3), 1, [new OnDayOfMonth(1)]);

        var all = RecurrenceGenerator.Ended(rule).ToList();
        Assert.Equal([D(2026, 1, 1), D(2026, 2, 1), D(2026, 3, 1)], all);

        // A window past the end yields nothing.
        Assert.Empty(Window(rule, D(2026, 4, 1), D(2026, 12, 31)));
    }

    [Fact]
    public void EndsOnDate_IsInclusive()
    {
        var rule = new DailyRule(D(2026, 1, 1), new EndsOnDate(D(2026, 1, 11)), 5);

        var dates = RecurrenceGenerator.Ended(rule).ToList();

        Assert.Equal([D(2026, 1, 1), D(2026, 1, 6), D(2026, 1, 11)], dates);
    }

    [Fact]
    public void From_Take_YieldsNextN_OfOpenEndedRule()
    {
        var rule = new MonthlyRule(D(2020, 1, 15), Never, 1, [new OnDayOfMonth(15)]);

        var next3 = RecurrenceGenerator.From(rule, D(2026, 6, 20)).Take(3).ToList();

        Assert.Equal([D(2026, 7, 15), D(2026, 8, 15), D(2026, 9, 15)], next3);
    }

    [Fact]
    public void Window_BeforeStart_YieldsNothing()
    {
        var rule = new DailyRule(D(2026, 6, 1), Never, 1);

        Assert.Empty(Window(rule, D(2026, 1, 1), D(2026, 5, 31)));
    }
}

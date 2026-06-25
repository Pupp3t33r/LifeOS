using LifeOS.Money.Api.Domain;
using Xunit;

namespace LifeOS.Money.Tests.Domain;

public class MonthPeriodTests
{
    [Fact]
    public void Anchor_WithDayOne_IsFirstOfCalendarMonth()
    {
        Assert.Equal(new DateOnly(2026, 3, 1), MonthPeriod.Anchor(2026, 3, 1));
    }

    [Fact]
    public void Anchor_WithDayInRange_IsThatDay()
    {
        Assert.Equal(new DateOnly(2026, 3, 25), MonthPeriod.Anchor(2026, 3, 25));
    }

    [Fact]
    public void Anchor_ClampsToLastDay_WhenMonthShorterThanDay()
    {
        // February 2026 has 28 days; day 31 clamps to the 28th.
        Assert.Equal(new DateOnly(2026, 2, 28), MonthPeriod.Anchor(2026, 2, 31));
    }

    [Fact]
    public void Anchor_ClampsToLeapDay_InLeapFebruary()
    {
        Assert.Equal(new DateOnly(2024, 2, 29), MonthPeriod.Anchor(2024, 2, 31));
    }

    [Fact]
    public void Span_WithDayOne_IsExactlyTheCalendarMonth()
    {
        var (start, end) = MonthPeriod.Span(2026, 3, 1);
        Assert.Equal(new DateOnly(2026, 3, 1), start);
        Assert.Equal(new DateOnly(2026, 4, 1), end);
    }

    [Fact]
    public void Span_WithCustomDay_RunsFromAnchorToNextAnchor()
    {
        var (start, end) = MonthPeriod.Span(2026, 3, 25);
        Assert.Equal(new DateOnly(2026, 3, 25), start);
        Assert.Equal(new DateOnly(2026, 4, 25), end);
    }

    [Fact]
    public void Span_RollsAcrossYearBoundary_InDecember()
    {
        var (start, end) = MonthPeriod.Span(2026, 12, 25);
        Assert.Equal(new DateOnly(2026, 12, 25), start);
        Assert.Equal(new DateOnly(2027, 1, 25), end);
    }

    [Fact]
    public void Span_WithHighDay_TilesCleanlyAcrossShortFebruary()
    {
        // Day 31: Jan-anchored period ends where Feb-anchored period begins, etc.
        var january = MonthPeriod.Span(2026, 1, 31);
        var february = MonthPeriod.Span(2026, 2, 31);

        Assert.Equal(new DateOnly(2026, 1, 31), january.Start);
        Assert.Equal(new DateOnly(2026, 2, 28), january.EndExclusive);
        Assert.Equal(new DateOnly(2026, 2, 28), february.Start);
        Assert.Equal(new DateOnly(2026, 3, 31), february.EndExclusive);
    }

    [Theory]
    [InlineData(1)]
    [InlineData(15)]
    [InlineData(28)]
    [InlineData(31)]
    public void Spans_TilePerfectly_EachEndIsTheNextStart(int monthStartDay)
    {
        // Walk a full year: every period's end must equal the next period's start —
        // no gaps, no overlaps — regardless of clamping.
        for (var month = 1; month <= 12; month++)
        {
            var current = MonthPeriod.Span(2026, month, monthStartDay);
            var (nextYear, nextMonth) = MonthPeriod.Next(2026, month);
            var next = MonthPeriod.Span(nextYear, nextMonth, monthStartDay);
            Assert.Equal(current.EndExclusive, next.Start);
        }
    }

    [Fact]
    public void ContainingPeriod_WithDayOne_IsTheCalendarMonth()
    {
        Assert.Equal((2026, 3), MonthPeriod.ContainingPeriod(new DateOnly(2026, 3, 15), 1));
    }

    [Theory]
    [InlineData(2026, 3, 24, 2026, 2)] // before the 25th anchor → previous period
    [InlineData(2026, 3, 25, 2026, 3)] // on the anchor → this period
    [InlineData(2026, 3, 26, 2026, 3)] // after the anchor → this period
    [InlineData(2026, 4, 10, 2026, 3)] // mid-period → the period that began Mar 25
    public void ContainingPeriod_WithCustomDay_BucketsByAnchor(
        int year, int month, int day, int expectedYear, int expectedMonth)
    {
        Assert.Equal(
            (expectedYear, expectedMonth),
            MonthPeriod.ContainingPeriod(new DateOnly(year, month, day), 25));
    }

    [Fact]
    public void ContainingPeriod_BeforeJanuaryAnchor_RollsToPreviousDecember()
    {
        Assert.Equal((2025, 12), MonthPeriod.ContainingPeriod(new DateOnly(2026, 1, 10), 25));
    }

    [Fact]
    public void Next_And_Previous_RollTheYear()
    {
        Assert.Equal((2027, 1), MonthPeriod.Next(2026, 12));
        Assert.Equal((2025, 12), MonthPeriod.Previous(2026, 1));
    }
}

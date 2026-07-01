namespace LifeOS.Money.Api.Domain.Recurring;

/// Computes the occurrence dates of a Live <see cref="RecurrenceRule"/> (ADR-0017).
/// Pure and deterministic: the same rule yields the same dates on the server and on
/// the Dart client (parity). Occurrences are always produced in ascending order.
///
/// The core is <see cref="Ended"/> — the rule's full ordered series with its
/// <see cref="RecurrenceEnd"/> applied — off which the bounded queries are built. The
/// raw per-kind sequences are lazy and guarded against running past
/// <see cref="DateOnly.MaxValue"/>, so an open-ended rule is safe to enumerate as
/// long as the caller bounds it (a window or <c>Take</c>).
public static class RecurrenceGenerator
{
    /// Occurrences within the inclusive window <c>[start, endInclusive]</c>.
    public static IEnumerable<DateOnly> InWindow(RecurrenceRule rule, DateOnly start, DateOnly endInclusive)
    {
        foreach (var date in Ended(rule))
        {
            if (date > endInclusive)
            {
                yield break;
            }

            if (date >= start)
            {
                yield return date;
            }
        }
    }

    /// Occurrences on or after <paramref name="fromInclusive"/>, ascending. Lazy —
    /// combine with <c>Take(n)</c> for "the next N occurrences" of an open-ended rule.
    public static IEnumerable<DateOnly> From(RecurrenceRule rule, DateOnly fromInclusive)
    {
        return Ended(rule).SkipWhile(x => x < fromInclusive);
    }

    /// The rule's complete ordered series with its end applied. Finite for
    /// <see cref="EndsOnDate"/> / <see cref="EndsAfter"/>; unbounded (up to
    /// <see cref="DateOnly.MaxValue"/>) for <see cref="NeverEnds"/>.
    public static IEnumerable<DateOnly> Ended(RecurrenceRule rule)
    {
        var count = 0;
        foreach (var date in Raw(rule))
        {
            switch (rule.End)
            {
                case EndsAfter afterCount when count >= afterCount.Count:
                    yield break;
                case EndsOnDate onDate when date > onDate.Date:
                    yield break;
            }

            yield return date;
            count++;
        }
    }

    // The unbounded ascending series from Start, ignoring End. Exhaustive over the
    // rule subtypes — a new subtype is a compile error here until handled.
    private static IEnumerable<DateOnly> Raw(RecurrenceRule rule) => rule switch
    {
        DailyRule daily => Daily(daily),
        WeeklyRule weekly => Weekly(weekly),
        MonthlyRule monthly => Monthly(monthly),
        YearlyRule yearly => Yearly(yearly),
        _ => throw new ArgumentOutOfRangeException(
            nameof(rule), rule.GetType().Name, "Unhandled recurrence rule kind."),
    };

    private static IEnumerable<DateOnly> Daily(DailyRule rule)
    {
        var interval = Require(rule.IntervalDays, nameof(rule.IntervalDays));
        var date = rule.Start;
        while (true)
        {
            yield return date;
            if (!TryAddDays(date, interval, out date))
            {
                yield break;
            }
        }
    }

    private static IEnumerable<DateOnly> Weekly(WeeklyRule rule)
    {
        var interval = Require(rule.IntervalWeeks, nameof(rule.IntervalWeeks));
        if (rule.Weekdays.Count == 0)
        {
            throw new ArgumentException("A weekly rule needs at least one weekday.", nameof(rule.Weekdays));
        }

        // Offsets from the Monday of any week, ascending (Mon=0 … Sun=6), de-duped.
        var offsets = rule.Weekdays.Select(MondayOffset).Distinct().OrderBy(x => x).ToArray();
        var weekStep = interval * 7;

        var blockMonday = MondayOf(rule.Start);
        while (true)
        {
            foreach (var offset in offsets)
            {
                var date = blockMonday.AddDays(offset);
                if (date >= rule.Start)
                {
                    yield return date;
                }
            }

            if (!TryAddDays(blockMonday, weekStep, out blockMonday))
            {
                yield break;
            }
        }
    }

    private static IEnumerable<DateOnly> Monthly(MonthlyRule rule)
    {
        var interval = Require(rule.IntervalMonths, nameof(rule.IntervalMonths));
        if (rule.Days.Count == 0)
        {
            throw new ArgumentException("A monthly rule needs at least one day anchor.", nameof(rule.Days));
        }

        var monthIndex = MonthIndex(rule.Start.Year, rule.Start.Month);
        while (true)
        {
            var (year, month) = FromMonthIndex(monthIndex);
            var daysInMonth = DateTime.DaysInMonth(year, month);

            var dates = new List<DateOnly>(rule.Days.Count);
            foreach (var anchor in rule.Days)
            {
                var day = anchor switch
                {
                    OnDayOfMonth onDay => Math.Min(RequireDay(onDay.Day), daysInMonth),
                    LastDayOfMonth => daysInMonth,
                    _ => throw new ArgumentOutOfRangeException(
                        nameof(rule), anchor.GetType().Name, "Unhandled month-day anchor."),
                };

                var date = new DateOnly(year, month, day);
                if (date >= rule.Start)
                {
                    dates.Add(date);
                }
            }

            foreach (var date in dates.Distinct().OrderBy(x => x))
            {
                yield return date;
            }

            // Guard: stop before the next block's year overflows DateOnly's range.
            var (nextYear, _) = FromMonthIndex(monthIndex + interval);
            if (nextYear > 9999)
            {
                yield break;
            }

            monthIndex += interval;
        }
    }

    private static IEnumerable<DateOnly> Yearly(YearlyRule rule)
    {
        var interval = Require(rule.IntervalYears, nameof(rule.IntervalYears));
        if (rule.Dates.Count == 0)
        {
            throw new ArgumentException("A yearly rule needs at least one date.", nameof(rule.Dates));
        }

        var year = rule.Start.Year;
        while (true)
        {
            var dates = new List<DateOnly>(rule.Dates.Count);
            foreach (var annual in rule.Dates)
            {
                var daysInMonth = DateTime.DaysInMonth(year, annual.Month);
                var day = Math.Min(RequireDay(annual.Day), daysInMonth);
                var date = new DateOnly(year, annual.Month, day);
                if (date >= rule.Start)
                {
                    dates.Add(date);
                }
            }

            foreach (var date in dates.Distinct().OrderBy(x => x))
            {
                yield return date;
            }

            if (year > 9999 - interval)
            {
                yield break;
            }

            year += interval;
        }
    }

    private static int MondayOffset(DayOfWeek day) => ((int)day + 6) % 7;

    private static DateOnly MondayOf(DateOnly date) => date.AddDays(-MondayOffset(date.DayOfWeek));

    private static int MonthIndex(int year, int month) => (year * 12) + (month - 1);

    private static (int Year, int Month) FromMonthIndex(int index) => (index / 12, (index % 12) + 1);

    private static bool TryAddDays(DateOnly date, int days, out DateOnly result)
    {
        if (date.DayNumber + (long)days > DateOnly.MaxValue.DayNumber)
        {
            result = date;
            return false;
        }

        result = date.AddDays(days);
        return true;
    }

    private static int Require(int interval, string name)
    {
        if (interval < 1)
        {
            throw new ArgumentOutOfRangeException(name, interval, "Interval must be at least 1.");
        }

        return interval;
    }

    private static int RequireDay(int day)
    {
        if (day is < 1 or > 31)
        {
            throw new ArgumentOutOfRangeException(nameof(day), day, "Day of month must be 1–31.");
        }

        return day;
    }
}

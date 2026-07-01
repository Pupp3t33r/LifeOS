using LifeOS.Money.Api.Domain.Recurring;
using LifeOS.Money.Api.Http;

namespace LifeOS.Money.Api.Features.Recurring;

/// Validates a recurrence rule's content (intervals ≥ 1, non-empty anchor sets, sane
/// day/month ranges) at the API boundary, throwing a 400 with a clear message. The
/// generator enforces the same invariants as a backstop, but that surfaces as a 500 —
/// so the client-facing check lives here.
internal static class RecurringRuleValidation
{
    public static void Validate(RecurrenceRule rule)
    {
        var error = rule switch
        {
            DailyRule daily => daily.IntervalDays < 1 ? "IntervalDays must be at least 1." : null,
            WeeklyRule weekly => weekly.IntervalWeeks < 1 ? "IntervalWeeks must be at least 1."
                : weekly.Weekdays.Count == 0 ? "A weekly rule needs at least one weekday." : null,
            MonthlyRule monthly => monthly.IntervalMonths < 1 ? "IntervalMonths must be at least 1."
                : monthly.Days.Count == 0 ? "A monthly rule needs at least one day anchor."
                : InvalidAnchor(monthly.Days),
            YearlyRule yearly => yearly.IntervalYears < 1 ? "IntervalYears must be at least 1."
                : yearly.Dates.Count == 0 ? "A yearly rule needs at least one date."
                : InvalidAnnualDate(yearly.Dates),
            _ => "Unknown recurrence rule kind.",
        };

        if (error is not null)
        {
            throw new BadRequestException(error);
        }
    }

    private static string? InvalidAnchor(IReadOnlyList<MonthDayAnchor> anchors) =>
        anchors.OfType<OnDayOfMonth>().Any(x => x.Day is < 1 or > 31)
            ? "Day of month must be between 1 and 31."
            : null;

    private static string? InvalidAnnualDate(IReadOnlyList<AnnualDate> dates) =>
        dates.Any(x => x.Month is < 1 or > 12 || x.Day is < 1 or > 31)
            ? "Annual date month must be 1–12 and day 1–31."
            : null;
}

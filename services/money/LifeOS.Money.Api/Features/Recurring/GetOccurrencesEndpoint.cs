using System.Globalization;
using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Domain.Recurring;
using Wolverine.Http;
using Wolverine.Marten;

namespace LifeOS.Money.Api.Features.Recurring;

public static class GetOccurrencesEndpoint
{
    // Occurrences due in a window (ADR-0017): computed from the rule (Live) or listed
    // from the schedule (Materialized), with the expected amount and each occurrence's
    // stable reference. Status (projected/paid/skipped) joins in Part B once confirm/
    // skip on the AccountingPeriod exists. `from`/`to` are read off the query string
    // (default: today .. +1 year); Live results are capped to keep the window bounded.
    private const int LiveOccurrenceCap = 500;

    [WolverineGet("/recurring/{id}/occurrences")]
    public static IReadOnlyList<OccurrenceResponse> Handle(
        Guid id,
        HttpContext context,
        [ReadAggregate] RecurringPayment recurring)
    {
        RecurringGuards.RequireOwner(recurring, context);

        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var from = ParseDate(context.Request.Query["from"]) ?? today;
        var to = ParseDate(context.Request.Query["to"]) ?? from.AddYears(1);
        if (to < from)
        {
            return [];
        }

        if (recurring.Mode == ScheduleMode.Live)
        {
            var expected = new CurrencyAmount(
                recurring.EstimateLines.Sum(x => x.Amount.Amount), recurring.Currency);

            return RecurrenceGenerator.InWindow(recurring.Rule!, from, to)
                .Take(LiveOccurrenceCap)
                .Select(date => new OccurrenceResponse(
                    date, date.ToString("yyyy-MM-dd"), expected, recurring.EstimateLines))
                .ToList();
        }

        return recurring.ScheduleLines
            .Where(x => x.DueDate >= from && x.DueDate <= to)
            .OrderBy(x => x.DueDate)
            .Select(x => new OccurrenceResponse(
                x.DueDate,
                x.LineId.ToString(),
                new CurrencyAmount(x.Total, recurring.Currency),
                x.Lines))
            .ToList();
    }

    private static DateOnly? ParseDate(string? value) =>
        DateOnly.TryParse(value, CultureInfo.InvariantCulture, out var parsed) ? parsed : null;
}

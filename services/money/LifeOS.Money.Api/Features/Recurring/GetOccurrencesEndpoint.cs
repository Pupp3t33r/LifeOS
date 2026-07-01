using System.Globalization;
using LifeOS.Money.Api.Auth;
using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Domain.Recurring;
using LifeOS.Money.Api.Projections;
using Marten;
using Wolverine.Http;
using Wolverine.Marten;

namespace LifeOS.Money.Api.Features.Recurring;

public static class GetOccurrencesEndpoint
{
    // Occurrences due in a window (ADR-0017), each with its status: computed from the
    // rule (Live) or listed from the schedule (Materialized), then joined against the
    // period back-references to derive projected / paid / skipped. This is the
    // RecurringScheduleProjection role, computed at read (the recurring aggregate
    // stores no occurrence state). `from`/`to` are read off the query string
    // (default: today .. +1 year); Live results are capped to keep the window bounded.
    private const int LiveOccurrenceCap = 500;

    [WolverineGet("/recurring/{id}/occurrences")]
    public static async Task<IReadOnlyList<OccurrenceResponse>> Handle(
        Guid id,
        HttpContext context,
        [ReadAggregate] RecurringPayment recurring,
        IQuerySession session)
    {
        RecurringGuards.RequireOwner(recurring, context);
        var userId = context.GetUserId();

        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var from = ParseDate(context.Request.Query["from"]) ?? today;
        var to = ParseDate(context.Request.Query["to"]) ?? from.AddYears(1);
        if (to < from)
        {
            return [];
        }

        // Occurrence status join: paid (a confirming FlowRecorded back-ref, newest
        // wins) and skipped (an OccurrenceSkipped), keyed by occurrence ref.
        var paid = (await session.Query<FlowEntryRecord>()
                .Where(x => x.OwnerId == userId && x.Recurring!.RecurringId == id)
                .ToListAsync())
            .GroupBy(x => x.Recurring!.OccurrenceRef)
            .ToDictionary(x => x.Key, x => x.OrderByDescending(y => y.RecordedAt).First());

        var skipped = (await session.Query<SkippedOccurrenceRecord>()
                .Where(x => x.OwnerId == userId && x.RecurringId == id)
                .ToListAsync())
            .Select(x => x.OccurrenceRef)
            .ToHashSet();

        OccurrenceResponse Build(DateOnly dueDate, string occurrenceRef, CurrencyAmount expected, IReadOnlyList<Line> lines)
        {
            if (paid.TryGetValue(occurrenceRef, out var entry))
            {
                return new OccurrenceResponse(dueDate, occurrenceRef, expected, lines, "paid",
                    entry.Total, DateOnly.FromDateTime(entry.OccurredAt.UtcDateTime));
            }

            if (skipped.Contains(occurrenceRef))
            {
                return new OccurrenceResponse(dueDate, occurrenceRef, expected, lines, "skipped", null, null);
            }

            return new OccurrenceResponse(dueDate, occurrenceRef, expected, lines, "projected", null, null);
        }

        if (recurring.Mode == ScheduleMode.Live)
        {
            var expected = new CurrencyAmount(
                recurring.EstimateLines.Sum(x => x.Amount.Amount), recurring.Currency);

            return RecurrenceGenerator.InWindow(recurring.Rule!, from, to)
                .Take(LiveOccurrenceCap)
                .Select(date => Build(date, date.ToString("yyyy-MM-dd"), expected, recurring.EstimateLines))
                .ToList();
        }

        return recurring.ScheduleLines
            .Where(x => x.DueDate >= from && x.DueDate <= to)
            .OrderBy(x => x.DueDate)
            .Select(x => Build(
                x.DueDate, x.LineId.ToString(), new CurrencyAmount(x.Total, recurring.Currency), x.Lines))
            .ToList();
    }

    private static DateOnly? ParseDate(string? value) =>
        DateOnly.TryParse(value, CultureInfo.InvariantCulture, out var parsed) ? parsed : null;
}

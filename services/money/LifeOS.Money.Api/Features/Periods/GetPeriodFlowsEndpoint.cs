using LifeOS.Money.Api.Auth;
using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Domain.Events;
using LifeOS.Money.Api.Projections;
using Marten;
using Wolverine.Http;

namespace LifeOS.Money.Api.Features.Periods;

public static class GetPeriodFlowsEndpoint
{
    // The current-period read-model behind the Wallet cockpit: the caller's recorded
    // flow entries for one period (ADR-0016), newest first, plus per-currency net
    // totals. Owner-scoped — never another user's entries. Returns an empty period
    // (no entries, no totals) when nothing has been logged, rather than 404, so the
    // client can cache "this period is empty" without special-casing.
    [WolverineGet("/months/{year}/{month}")]
    public static async Task<PeriodFlowsResponse> Handle(
        int year,
        int month,
        HttpContext context,
        IQuerySession session)
    {
        var userId = context.GetUserId();

        var records = await session.Query<FlowEntryRecord>()
            .Where(x => x.OwnerId == userId && x.Year == year && x.Month == month)
            .ToListAsync();

        var entries = records
            .OrderByDescending(x => x.OccurredAt)
            .ThenByDescending(x => x.RecordedAt)
            .Select(ToResponse)
            .ToList();

        var totals = records
            .GroupBy(x => x.Total.Currency)
            .Select(x => new CurrencyAmount(x.Sum(y => y.Total.Amount), x.Key))
            .OrderBy(x => x.Currency)
            .ToList();

        return new PeriodFlowsResponse(year, month, entries, totals);
    }

    private static FlowEntryResponse ToResponse(FlowEntryRecord record)
    {
        return new FlowEntryResponse(
            record.Id,
            record.Direction == FlowDirection.In ? "in" : "out",
            record.Lines,
            record.Total,
            record.OccurredAt,
            record.RecordedAt,
            record.Description);
    }
}

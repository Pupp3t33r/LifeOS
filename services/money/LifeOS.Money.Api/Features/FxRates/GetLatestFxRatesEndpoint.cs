using LifeOS.Money.Api.Domain.Fx;
using Marten;
using Wolverine.Http;

namespace LifeOS.Money.Api.Features.FxRates;

public static class GetLatestFxRatesEndpoint
{
    // Every source's newest rate per pair — one row per (Base, Quote, Source), NOT
    // collapsed by precedence. This is the shape the eventual client rate cache
    // (ADR-0015) and the future per-user source Settings (priority / on-off) need:
    // both must see what each source actually offers, not a single pre-resolved
    // answer. The single-pair GET /fx-rates applies precedence; this one does not.
    [WolverineGet("/fx-rates/latest")]
    public static async Task<IReadOnlyList<FxRateResponse>> Handle(IQuerySession session)
    {
        var all = await session.Query<FxRate>().ToListAsync();

        return all
            .GroupBy(x => (x.Base, x.Quote, x.Source))
            .Select(x => x.OrderByDescending(y => y.Date).First())
            .OrderBy(x => x.Base)
            .ThenBy(x => x.Quote)
            .ThenBy(x => x.Source)
            .Select(x => new FxRateResponse(x.Base, x.Quote, x.Rate, x.Date, x.Source))
            .ToList();
    }
}

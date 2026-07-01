using System.Globalization;
using LifeOS.Money.Api.Domain.Fx;
using LifeOS.Money.Api.Fx;
using LifeOS.Money.Api.Http;
using Marten;
using Microsoft.Extensions.Options;
using Wolverine.Http;

namespace LifeOS.Money.Api.Features.FxRates;

public static class GetFxRateEndpoint
{
    // Resolve one rate: base -> quote as of a date (default today), with forward-fill
    // and source precedence (ADR-0015). Rates are shared reference data, not
    // owner-scoped. When the pair is not stored directly, the inverse pair is tried
    // and reciprocated. 404 when no source covers the pair on/before the date.
    //
    // Query params are read straight off HttpContext rather than bound as method
    // args: the natural name for the base-currency arg is the C# keyword `base`,
    // which Wolverine's codegen emits verbatim as a local (`var base = …`) and cannot
    // compile. Reading the query here keeps the `?base=&quote=&date=` contract intact.
    [WolverineGet("/fx-rates")]
    public static async Task<FxRateResponse> Handle(
        HttpContext context,
        IQuerySession session,
        IOptions<FxOptions> options)
    {
        var baseParam = context.Request.Query["base"].ToString();
        var quoteParam = context.Request.Query["quote"].ToString();
        var dateParam = context.Request.Query["date"].ToString();

        if (string.IsNullOrWhiteSpace(baseParam) || string.IsNullOrWhiteSpace(quoteParam))
        {
            throw new BadRequestException("Query parameters 'base' and 'quote' are required.");
        }

        var from = baseParam.ToUpperInvariant();
        var to = quoteParam.ToUpperInvariant();
        var asOf = DateOnly.TryParse(dateParam, CultureInfo.InvariantCulture, out var parsed)
            ? parsed
            : DateOnly.FromDateTime(DateTime.UtcNow);
        var priority = options.Value.SourcePriority;

        if (from == to)
        {
            return new FxRateResponse(from, to, 1m, asOf, "identity");
        }

        // Direct pair.
        var direct = await session.Query<FxRate>()
            .Where(x => x.Base == from && x.Quote == to)
            .ToListAsync();
        var resolved = FxRateResolver.Resolve(direct, asOf, priority);
        if (resolved is not null)
        {
            return ToResponse(resolved);
        }

        // Inverse pair, reciprocated (e.g. only BYN->USD stored, asked USD->BYN).
        var inverse = await session.Query<FxRate>()
            .Where(x => x.Base == to && x.Quote == from)
            .ToListAsync();
        var resolvedInverse = FxRateResolver.Resolve(inverse, asOf, priority);
        if (resolvedInverse is not null && resolvedInverse.Rate != 0)
        {
            return new FxRateResponse(
                from, to, 1m / resolvedInverse.Rate, resolvedInverse.Date, resolvedInverse.Source);
        }

        throw new NotFoundException(
            $"No FX rate for {from}->{to} on or before {asOf:yyyy-MM-dd}.");
    }

    private static FxRateResponse ToResponse(FxRate rate) =>
        new(rate.Base, rate.Quote, rate.Rate, rate.Date, rate.Source);
}

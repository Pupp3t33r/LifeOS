using System.Net;
using System.Net.Http.Json;
using LifeOS.Money.Api.Domain.Fx;
using LifeOS.Money.Api.Features.FxRates;
using LifeOS.Money.Tests.Infrastructure;
using Marten;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace LifeOS.Money.Tests.Features.FxRates;

public class FxRatesEndpointTests : IClassFixture<MoneyApiFactory>
{
    private readonly MoneyApiFactory _factory;

    public FxRatesEndpointTests(MoneyApiFactory factory) => _factory = factory;

    private async Task SeedAsync(params FxRate[] rows)
    {
        using var scope = _factory.Services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<IDocumentStore>();
        await using var session = store.LightweightSession();
        session.Store(rows);
        await session.SaveChangesAsync();
    }

    private static FxRate Rate(string @base, string quote, DateOnly date, decimal rate, string source) => new()
    {
        Id = FxRate.MakeId(@base, quote, date, source),
        Base = @base,
        Quote = quote,
        Date = date,
        Rate = rate,
        Source = source,
    };

    [Fact]
    public async Task SameCurrency_ReturnsIdentityRate()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);

        var body = await (await client.GetAsync("/api/fx-rates?base=USD&quote=USD"))
            .Content.ReadFromJsonAsync<FxRateResponse>();

        Assert.Equal(1m, body!.Rate);
        Assert.Equal("identity", body.Source);
    }

    [Fact]
    public async Task MissingParams_Returns400()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);

        var response = await client.GetAsync("/api/fx-rates?base=USD");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task UnknownPair_Returns404()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);

        var response = await client.GetAsync("/api/fx-rates?base=QQA&quote=QQB");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task DirectPair_AppliesPrecedenceAndForwardFill()
    {
        await SeedAsync(
            Rate("DAA", "DBB", new DateOnly(2026, 6, 28), 2.90m, FxSource.Belarusbank),
            Rate("DAA", "DBB", new DateOnly(2026, 7, 1), 3.10m, FxSource.Frankfurter));

        var client = _factory.CreateClientFor(TestUsers.Alice);

        // Asked as-of Jul 1: Belarusbank preferred (per-pair), its freshest row is Jun 28.
        var body = await (await client.GetAsync("/api/fx-rates?base=DAA&quote=DBB&date=2026-07-01"))
            .Content.ReadFromJsonAsync<FxRateResponse>();

        Assert.Equal(FxSource.Belarusbank, body!.Source);
        Assert.Equal(2.90m, body.Rate);
        Assert.Equal(new DateOnly(2026, 6, 28), body.Date);
    }

    [Fact]
    public async Task InversePair_IsReciprocated()
    {
        await SeedAsync(Rate("IAA", "IBB", new DateOnly(2026, 7, 1), 4m, FxSource.Belarusbank));

        var client = _factory.CreateClientFor(TestUsers.Alice);

        // Only IAA->IBB stored; asking IBB->IAA reciprocates to 1/4 = 0.25.
        var body = await (await client.GetAsync("/api/fx-rates?base=IBB&quote=IAA&date=2026-07-01"))
            .Content.ReadFromJsonAsync<FxRateResponse>();

        Assert.Equal(0.25m, body!.Rate);
    }

    [Fact]
    public async Task Latest_ReturnsRowPerPairAndSource()
    {
        await SeedAsync(
            Rate("LAA", "LBB", new DateOnly(2026, 6, 20), 1.00m, FxSource.Belarusbank),
            Rate("LAA", "LBB", new DateOnly(2026, 7, 1), 1.10m, FxSource.Belarusbank),
            Rate("LAA", "LBB", new DateOnly(2026, 7, 1), 1.20m, FxSource.Frankfurter));

        var client = _factory.CreateClientFor(TestUsers.Alice);

        var body = await (await client.GetAsync("/api/fx-rates/latest"))
            .Content.ReadFromJsonAsync<List<FxRateResponse>>();

        var mine = body!.Where(x => x is { Base: "LAA", Quote: "LBB" }).ToList();
        // One row per source, each the newest for that source.
        Assert.Equal(2, mine.Count);
        var bank = Assert.Single(mine, x => x.Source == FxSource.Belarusbank);
        Assert.Equal(1.10m, bank.Rate); // Jul 1, not the older Jun 20
        var frank = Assert.Single(mine, x => x.Source == FxSource.Frankfurter);
        Assert.Equal(1.20m, frank.Rate);
    }
}

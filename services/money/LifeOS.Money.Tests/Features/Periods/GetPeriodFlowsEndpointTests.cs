using System.Net;
using System.Net.Http.Json;
using LifeOS.Money.Api.Features.Flows;
using LifeOS.Money.Api.Features.Periods;
using LifeOS.Money.Tests.Infrastructure;

namespace LifeOS.Money.Tests.Features.Periods;

public class GetPeriodFlowsEndpointTests : IClassFixture<MoneyApiFactory>
{
    private readonly MoneyApiFactory _factory;

    public GetPeriodFlowsEndpointTests(MoneyApiFactory factory) => _factory = factory;

    [Fact]
    public async Task Returns200_EmptyPeriod_WhenNothingLogged()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);

        var response = await client.GetAsync("/api/months/2099/1");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<PeriodFlowsResponse>();
        Assert.NotNull(body);
        Assert.Empty(body!.Entries);
        Assert.Empty(body.Totals);
    }

    [Fact]
    public async Task ListsRecordedEntries_WithSignedTotalsAndDirection()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);

        await client.PostAsJsonAsync(
            "/api/months/2026/3/transactions",
            new RecordFlowRequest(Guid.NewGuid(), "out", "USD", DateTimeOffset.Parse("2026-03-10T00:00:00Z"), "Lidl",
                [new RecordFlowLine(34m, null, "Groceries")]));
        await client.PostAsJsonAsync(
            "/api/months/2026/3/transactions",
            new RecordFlowRequest(Guid.NewGuid(), "in", "USD", DateTimeOffset.Parse("2026-03-12T00:00:00Z"), "Refund",
                [new RecordFlowLine(120m, null, null)]));

        var body = await (await client.GetAsync("/api/months/2026/3"))
            .Content.ReadFromJsonAsync<PeriodFlowsResponse>();

        Assert.NotNull(body);
        Assert.Equal(2, body!.Entries.Count);
        // Newest occurredAt first: the income (Mar 12) precedes the expense (Mar 10).
        Assert.Equal("in", body.Entries[0].Direction);
        Assert.Equal(120m, body.Entries[0].Total.Amount);
        Assert.Equal("out", body.Entries[1].Direction);
        Assert.Equal(-34m, body.Entries[1].Total.Amount);
        // Net: 120 - 34 = 86 USD.
        var usd = Assert.Single(body.Totals);
        Assert.Equal("USD", usd.Currency);
        Assert.Equal(86m, usd.Amount);
    }

    [Fact]
    public async Task GroupsNetTotalsPerCurrency()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);

        await client.PostAsJsonAsync(
            "/api/months/2026/2/transactions",
            new RecordFlowRequest(Guid.NewGuid(), "out", "USD", DateTimeOffset.Parse("2026-02-02T00:00:00Z"), null,
                [new RecordFlowLine(50m, null, null)]));
        await client.PostAsJsonAsync(
            "/api/months/2026/2/transactions",
            new RecordFlowRequest(Guid.NewGuid(), "out", "EUR", DateTimeOffset.Parse("2026-02-03T00:00:00Z"), null,
                [new RecordFlowLine(80m, null, null)]));

        var body = await (await client.GetAsync("/api/months/2026/2"))
            .Content.ReadFromJsonAsync<PeriodFlowsResponse>();

        Assert.Equal(2, body!.Totals.Count);
        Assert.Equal("EUR", body.Totals[0].Currency); // ordered by currency
        Assert.Equal(-80m, body.Totals[0].Amount);
        Assert.Equal("USD", body.Totals[1].Currency);
        Assert.Equal(-50m, body.Totals[1].Amount);
    }

    [Fact]
    public async Task IsOwnerScoped_DoesNotLeakOtherUsersEntries()
    {
        var alice = _factory.CreateClientFor(TestUsers.Alice);
        var bob = _factory.CreateClientFor(TestUsers.Bob);

        await alice.PostAsJsonAsync(
            "/api/months/2026/4/transactions",
            new RecordFlowRequest(Guid.NewGuid(), "out", "USD", DateTimeOffset.Parse("2026-04-01T00:00:00Z"), "Alice only",
                [new RecordFlowLine(10m, null, null)]));

        var body = await (await bob.GetAsync("/api/months/2026/4"))
            .Content.ReadFromJsonAsync<PeriodFlowsResponse>();

        Assert.Empty(body!.Entries);
    }
}

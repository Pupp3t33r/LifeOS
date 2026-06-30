using System.Net;
using System.Net.Http.Json;
using LifeOS.Money.Api.Features.Flows;
using LifeOS.Money.Tests.Infrastructure;

namespace LifeOS.Money.Tests.Features.Flows;

public class RecordFlowEndpointTests : IClassFixture<MoneyApiFactory>
{
    private readonly MoneyApiFactory _factory;

    public RecordFlowEndpointTests(MoneyApiFactory factory) => _factory = factory;

    [Fact]
    public async Task Returns200_OnSingleLineExpense_TotalIsNegative()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);

        var response = await client.PostAsJsonAsync(
            "/api/months/2026/6/transactions",
            new RecordFlowRequest(
                Guid.NewGuid(), "out", "USD", DateTimeOffset.UtcNow, "Lidl",
                [new RecordFlowLine(34m, null, "Groceries")]));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<RecordFlowResponse>();
        Assert.NotNull(body);
        Assert.Equal(-34m, body!.Total.Amount);
        Assert.Equal("USD", body.Total.Currency);
    }

    [Fact]
    public async Task Returns200_OnMultiLine_TotalIsSumOfSignedLines()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);

        var response = await client.PostAsJsonAsync(
            "/api/months/2026/6/transactions",
            new RecordFlowRequest(
                Guid.NewGuid(), "out", "USD", DateTimeOffset.UtcNow, "Costco run",
                [
                    new RecordFlowLine(62m, null, "Bulk groceries"),
                    new RecordFlowLine(34m, null, "Household"),
                    new RecordFlowLine(16m, null, "Wine"),
                ]));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<RecordFlowResponse>();
        Assert.Equal(-112m, body!.Total.Amount);
        Assert.Equal(3, body.Lines.Count);
    }

    [Fact]
    public async Task Returns200_OnIncome_TotalIsPositive()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);

        var response = await client.PostAsJsonAsync(
            "/api/months/2026/6/transactions",
            new RecordFlowRequest(
                Guid.NewGuid(), "in", "USD", DateTimeOffset.UtcNow, "Refund",
                [new RecordFlowLine(120m, null, null)]));

        var body = await response.Content.ReadFromJsonAsync<RecordFlowResponse>();
        Assert.Equal(120m, body!.Total.Amount);
    }

    [Fact]
    public async Task Returns409_OnDuplicateEntryId()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);
        var entryId = Guid.NewGuid();

        var first = await client.PostAsJsonAsync(
            "/api/months/2026/6/transactions",
            new RecordFlowRequest(entryId, "out", "USD", DateTimeOffset.UtcNow, "first",
                [new RecordFlowLine(10m, null, null)]));
        first.EnsureSuccessStatusCode();

        var second = await client.PostAsJsonAsync(
            "/api/months/2026/6/transactions",
            new RecordFlowRequest(entryId, "out", "USD", DateTimeOffset.UtcNow, "duplicate",
                [new RecordFlowLine(10m, null, null)]));

        Assert.Equal(HttpStatusCode.Conflict, second.StatusCode);
    }

    [Fact]
    public async Task Returns400_OnNoLines()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);

        var response = await client.PostAsJsonAsync(
            "/api/months/2026/6/transactions",
            new RecordFlowRequest(Guid.NewGuid(), "out", "USD", DateTimeOffset.UtcNow, null,
                []));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Returns400_OnZeroLineAmount()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);

        var response = await client.PostAsJsonAsync(
            "/api/months/2026/6/transactions",
            new RecordFlowRequest(Guid.NewGuid(), "out", "USD", DateTimeOffset.UtcNow, null,
                [new RecordFlowLine(0m, null, null)]));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Returns400_OnBadDirection()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);

        var response = await client.PostAsJsonAsync(
            "/api/months/2026/6/transactions",
            new RecordFlowRequest(Guid.NewGuid(), "sideways", "USD", DateTimeOffset.UtcNow, null,
                [new RecordFlowLine(10m, null, null)]));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Returns400_OnFutureOccurredAt()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);

        var response = await client.PostAsJsonAsync(
            "/api/months/2026/6/transactions",
            new RecordFlowRequest(Guid.NewGuid(), "out", "USD", DateTimeOffset.UtcNow.AddHours(1), null,
                [new RecordFlowLine(10m, null, null)]));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }
}

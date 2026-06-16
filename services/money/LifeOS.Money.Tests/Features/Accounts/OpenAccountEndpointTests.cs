using System.Net;
using System.Net.Http.Json;
using LifeOS.Money.Api.Features.Accounts;
using LifeOS.Money.Tests.Infrastructure;

namespace LifeOS.Money.Tests.Features.Accounts;

public class OpenAccountEndpointTests : IClassFixture<MoneyApiFactory>
{
    private readonly MoneyApiFactory _factory;

    public OpenAccountEndpointTests(MoneyApiFactory factory) => _factory = factory;

    [Fact]
    public async Task Returns201_AndPersistsAccount()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);
        var accountId = Guid.NewGuid();
        var request = new OpenAccountRequest(accountId, "Main Savings", "EUR", 1000m);

        var response = await client.PostAsJsonAsync("/api/accounts", request);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        Assert.Equal($"/api/accounts/{accountId}", response.Headers.Location?.ToString());

        var body = await response.Content.ReadFromJsonAsync<AccountResponse>();
        Assert.NotNull(body);
        Assert.Equal(accountId, body!.AccountId);
        Assert.Equal(TestUsers.Alice.Id, body.OwnerId);
        Assert.Equal("Main Savings", body.Name);
        Assert.Equal("EUR", body.Currency);
        Assert.Equal(1000m, body.Balance.Amount);
    }

    [Fact]
    public async Task IsIdempotent_WhenSameRequestRepeated()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);
        var accountId = Guid.NewGuid();
        var request = new OpenAccountRequest(accountId, "Repeatable", "USD", null);

        var first = await client.PostAsJsonAsync("/api/accounts", request);
        var second = await client.PostAsJsonAsync("/api/accounts", request);

        Assert.Equal(HttpStatusCode.Created, first.StatusCode);
        Assert.Equal(HttpStatusCode.Created, second.StatusCode);
    }

    [Fact]
    public async Task Returns409_WhenAccountIdExistsWithDifferentData()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);
        var accountId = Guid.NewGuid();
        await client.PostAsJsonAsync("/api/accounts", new OpenAccountRequest(accountId, "Name A", "EUR", null));

        var conflict = await client.PostAsJsonAsync(
            "/api/accounts",
            new OpenAccountRequest(accountId, "Name B", "EUR", null));

        Assert.Equal(HttpStatusCode.Conflict, conflict.StatusCode);
    }

    [Fact]
    public async Task Returns404_WhenAccountIdOwnedByAnotherUser()
    {
        var userA = _factory.CreateClientFor(TestUsers.Alice);
        var userB = _factory.CreateClientFor(TestUsers.Bob);
        var accountId = Guid.NewGuid();

        await userA.PostAsJsonAsync("/api/accounts", new OpenAccountRequest(accountId, "Owned", "EUR", null));

        var byOtherUser = await userB.PostAsJsonAsync(
            "/api/accounts",
            new OpenAccountRequest(accountId, "Owned", "EUR", null));

        Assert.Equal(HttpStatusCode.NotFound, byOtherUser.StatusCode);
    }

    [Fact]
    public async Task Returns400_WhenAccountIdIsEmpty()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);
        var request = new OpenAccountRequest(Guid.Empty, "V", "EUR", null);

        var response = await client.PostAsJsonAsync("/api/accounts", request);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Returns400_WhenCurrencyIsNotIso4217()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);
        var request = new OpenAccountRequest(Guid.NewGuid(), "V", "eur", null);

        var response = await client.PostAsJsonAsync("/api/accounts", request);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Returns400_WhenOpeningBalanceIsNegative()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);
        var request = new OpenAccountRequest(Guid.NewGuid(), "V", "EUR", -10m);

        var response = await client.PostAsJsonAsync("/api/accounts", request);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }
}

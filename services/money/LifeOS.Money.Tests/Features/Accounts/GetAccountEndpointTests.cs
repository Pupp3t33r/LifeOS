using System.Net;
using System.Net.Http.Json;
using LifeOS.Money.Api.Features.Accounts;
using LifeOS.Money.Tests.Infrastructure;

namespace LifeOS.Money.Tests.Features.Accounts;

public class GetAccountEndpointTests : IClassFixture<MoneyApiFactory>
{
    private readonly MoneyApiFactory _factory;

    public GetAccountEndpointTests(MoneyApiFactory factory) => _factory = factory;

    [Fact]
    public async Task Returns200_WhenOwnedByCaller()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);
        var accountId = await CreateAccountAsync(client, "Mine", "EUR");

        var response = await client.GetAsync($"/api/accounts/{accountId}");
        var body = await response.Content.ReadFromJsonAsync<AccountResponse>();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.NotNull(body);
        Assert.Equal(accountId, body!.AccountId);
        Assert.Equal("Mine", body.Name);
    }

    [Fact]
    public async Task Returns404_WhenOwnedByAnotherUser()
    {
        var userA = _factory.CreateClientFor(TestUsers.Alice);
        var userB = _factory.CreateClientFor(TestUsers.Bob);
        var accountId = await CreateAccountAsync(userA, "Private", "EUR");

        var response = await userB.GetAsync($"/api/accounts/{accountId}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task Returns404_WhenAccountDoesNotExist()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);

        var response = await client.GetAsync($"/api/accounts/{Guid.NewGuid()}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    private static async Task<Guid> CreateAccountAsync(HttpClient client, string name, string currency)
    {
        var accountId = Guid.NewGuid();
        var response = await client.PostAsJsonAsync(
            "/api/accounts",
            new OpenAccountRequest(accountId, name, currency, null));
        response.EnsureSuccessStatusCode();
        return accountId;
    }
}

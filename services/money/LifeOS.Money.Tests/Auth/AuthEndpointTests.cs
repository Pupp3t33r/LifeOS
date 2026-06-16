using System.Net;
using System.Net.Http.Json;
using LifeOS.Money.Api.Features.Accounts;
using LifeOS.Money.Tests.Infrastructure;

namespace LifeOS.Money.Tests.Auth;

public class AuthEndpointTests : IClassFixture<MoneyApiFactory>
{
    private readonly MoneyApiFactory _factory;

    public AuthEndpointTests(MoneyApiFactory factory) => _factory = factory;

    [Fact]
    public async Task Returns401_WhenNoBearerToken()
    {
        var client = _factory.CreateClientWithoutAuth();

        var response = await client.GetAsync($"/api/accounts/{Guid.NewGuid()}");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Returns401_WhenBearerTokenIsExpired()
    {
        var client = _factory.CreateClient();
        var token = _factory.Jwt.Create(TestUsers.Alice.Id, TimeSpan.FromSeconds(-1));
        client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsJsonAsync(
            "/api/accounts",
            new OpenAccountRequest(Guid.NewGuid(), "X", "EUR", null));

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task HonorsUserIdFromToken_AndEnforcesOwnershipAcrossUsers()
    {
        var userA = _factory.CreateClientFor(TestUsers.Alice);
        var userB = _factory.CreateClientFor(TestUsers.Bob);

        var accountId = Guid.NewGuid();
        var created = await userA.PostAsJsonAsync(
            "/api/accounts",
            new OpenAccountRequest(accountId, "OwnedByA", "EUR", null));
        created.EnsureSuccessStatusCode();

        var bGet = await userB.GetAsync($"/api/accounts/{accountId}");
        Assert.Equal(HttpStatusCode.NotFound, bGet.StatusCode);

        var aGet = await userA.GetAsync($"/api/accounts/{accountId}");
        Assert.Equal(HttpStatusCode.OK, aGet.StatusCode);
    }
}

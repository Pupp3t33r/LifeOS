using System.Net;
using System.Net.Http.Json;
using LifeOS.Money.Api.Features.Accounts;
using LifeOS.Money.Api.Features.Transactions;
using LifeOS.Money.Tests.Infrastructure;

namespace LifeOS.Money.Tests.Features.Transactions;

public class RecordTransactionEndpointTests : IClassFixture<MoneyApiFactory>
{
    private readonly MoneyApiFactory _factory;

    public RecordTransactionEndpointTests(MoneyApiFactory factory) => _factory = factory;

    [Fact]
    public async Task Returns200_OnIncome_AndIncreasesBalance()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);
        var accountId = await CreateAccountAsync(client, "EUR", 1000m);

        var response = await client.PostAsJsonAsync(
            $"/api/accounts/{accountId}/transactions",
            new RecordTransactionRequest(Guid.NewGuid(), 250m, "EUR", "Salary", DateTimeOffset.UtcNow));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<RecordTransactionResponse>();
        Assert.NotNull(body);
        Assert.Equal(1250m, body!.NewBalance.Amount);
    }

    [Fact]
    public async Task Returns200_OnExpense_AndDecreasesBalance_VisibleInSubsequentGet()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);
        var accountId = await CreateAccountAsync(client, "EUR", 1000m);

        var txResponse = await client.PostAsJsonAsync(
            $"/api/accounts/{accountId}/transactions",
            new RecordTransactionRequest(Guid.NewGuid(), -50m, "EUR", "Groceries", DateTimeOffset.UtcNow));
        var tx = await txResponse.Content.ReadFromJsonAsync<RecordTransactionResponse>();

        Assert.Equal(950m, tx!.NewBalance.Amount);

        var account = await client.GetFromJsonAsync<AccountResponse>($"/api/accounts/{accountId}");
        Assert.Equal(950m, account!.Balance.Amount);
    }

    [Fact]
    public async Task Returns404_WhenAccountOwnedByAnotherUser()
    {
        var userA = _factory.CreateClientFor(TestUsers.Alice);
        var userB = _factory.CreateClientFor(TestUsers.Bob);
        var accountId = await CreateAccountAsync(userA, "EUR", null);

        var response = await userB.PostAsJsonAsync(
            $"/api/accounts/{accountId}/transactions",
            new RecordTransactionRequest(Guid.NewGuid(), -10m, "EUR", "x", DateTimeOffset.UtcNow));

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task Returns409_OnCurrencyMismatch()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);
        var accountId = await CreateAccountAsync(client, "EUR", null);

        var response = await client.PostAsJsonAsync(
            $"/api/accounts/{accountId}/transactions",
            new RecordTransactionRequest(Guid.NewGuid(), -10m, "USD", "mismatch", DateTimeOffset.UtcNow));

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
    }

    [Fact]
    public async Task Returns409_OnDuplicateTransactionId()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);
        var accountId = await CreateAccountAsync(client, "EUR", null);
        var txId = Guid.NewGuid();

        var first = await client.PostAsJsonAsync(
            $"/api/accounts/{accountId}/transactions",
            new RecordTransactionRequest(txId, -10m, "EUR", "first", DateTimeOffset.UtcNow));
        first.EnsureSuccessStatusCode();

        var second = await client.PostAsJsonAsync(
            $"/api/accounts/{accountId}/transactions",
            new RecordTransactionRequest(txId, -10m, "EUR", "duplicate", DateTimeOffset.UtcNow));

        Assert.Equal(HttpStatusCode.Conflict, second.StatusCode);
    }

    [Fact]
    public async Task Returns400_WhenAmountIsZero()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);
        var accountId = await CreateAccountAsync(client, "EUR", null);

        var response = await client.PostAsJsonAsync(
            $"/api/accounts/{accountId}/transactions",
            new RecordTransactionRequest(Guid.NewGuid(), 0m, "EUR", "zero", DateTimeOffset.UtcNow));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Returns400_WhenOccurredAtIsInTheFuture()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);
        var accountId = await CreateAccountAsync(client, "EUR", null);

        var response = await client.PostAsJsonAsync(
            $"/api/accounts/{accountId}/transactions",
            new RecordTransactionRequest(Guid.NewGuid(), -10m, "EUR", "future", DateTimeOffset.UtcNow.AddHours(1)));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    private static async Task<Guid> CreateAccountAsync(HttpClient client, string currency, decimal? openingBalance)
    {
        var accountId = Guid.NewGuid();
        var response = await client.PostAsJsonAsync(
            "/api/accounts",
            new OpenAccountRequest(accountId, "Test Account", currency, openingBalance));
        response.EnsureSuccessStatusCode();
        return accountId;
    }
}

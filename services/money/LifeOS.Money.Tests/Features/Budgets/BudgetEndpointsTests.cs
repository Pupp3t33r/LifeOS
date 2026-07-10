using System.Net.Http.Json;
using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Features.Budgets;
using LifeOS.Money.Tests.Infrastructure;

namespace LifeOS.Money.Tests.Features.Budgets;

public class BudgetEndpointsTests : IClassFixture<MoneyApiFactory> {
    private readonly MoneyApiFactory _factory;

    public BudgetEndpointsTests(MoneyApiFactory factory) => _factory = factory;

    private HttpClient NewUser() => _factory.CreateClientForUser(Guid.NewGuid().ToString());

    private static async Task<PeriodBudgetResponse> GetBudget(HttpClient client, int year, int month) {
        var res = await client.GetAsync($"/api/budgets?year={year}&month={month}");
        res.EnsureSuccessStatusCode();
        return (await res.Content.ReadFromJsonAsync<PeriodBudgetResponse>())!;
    }

    [Fact]
    public async Task Get_ReturnsEmptyDefault_WhenUnset() {
        var client = NewUser();

        var budget = await GetBudget(client, 2026, 8);

        Assert.Null(budget.SavingsTarget);
        Assert.Empty(budget.Limits);
        Assert.Empty(budget.TrackedCategories);
    }

    [Fact]
    public async Task Put_ThenGet_RoundTripsTargetLimitsAndTracked() {
        var client = NewUser();
        var coffee = Guid.NewGuid();
        var rent = Guid.NewGuid();

        var put = await client.PutAsJsonAsync("/api/budgets?year=2026&month=8", new PutBudgetRequest(
            new CurrencyAmount(1000m, "USD"),
            [new CategoryLimit(coffee, new CurrencyAmount(60m, "USD")),
             new CategoryLimit(rent, new CurrencyAmount(1200m, "USD"))],
            [coffee]));
        put.EnsureSuccessStatusCode();

        var budget = await GetBudget(client, 2026, 8);
        Assert.Equal(1000m, budget.SavingsTarget!.Amount);
        Assert.Equal(2, budget.Limits.Count);
        Assert.Equal(60m, budget.Limits.Single(x => x.CategoryId == coffee).Amount.Amount);
        Assert.Equal([coffee], budget.TrackedCategories);
    }

    [Fact]
    public async Task Put_Upserts_ReplacingTheWholeRecord() {
        var client = NewUser();
        var coffee = Guid.NewGuid();

        await client.PutAsJsonAsync("/api/budgets?year=2026&month=8", new PutBudgetRequest(
            new CurrencyAmount(1000m, "USD"),
            [new CategoryLimit(coffee, new CurrencyAmount(60m, "USD"))],
            [coffee]));

        // Second PUT clears the target and drops all limits.
        await client.PutAsJsonAsync("/api/budgets?year=2026&month=8", new PutBudgetRequest(
            null, [], []));

        var budget = await GetBudget(client, 2026, 8);
        Assert.Null(budget.SavingsTarget);
        Assert.Empty(budget.Limits);
        Assert.Empty(budget.TrackedCategories);
    }

    [Fact]
    public async Task Budget_IsPerPeriod() {
        var client = NewUser();
        await client.PutAsJsonAsync("/api/budgets?year=2026&month=8", new PutBudgetRequest(
            new CurrencyAmount(500m, "USD"), [], []));

        // A different period is independent.
        Assert.Null((await GetBudget(client, 2026, 9)).SavingsTarget);
        Assert.Equal(500m, (await GetBudget(client, 2026, 8)).SavingsTarget!.Amount);
    }

    [Fact]
    public async Task Budget_IsOwnerScoped() {
        var alice = _factory.CreateClientForUser(Guid.NewGuid().ToString());
        var bob = _factory.CreateClientForUser(Guid.NewGuid().ToString());
        await alice.PutAsJsonAsync("/api/budgets?year=2026&month=8", new PutBudgetRequest(
            new CurrencyAmount(999m, "USD"), [], []));

        Assert.Null((await GetBudget(bob, 2026, 8)).SavingsTarget);
    }
}

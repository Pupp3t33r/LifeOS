using System.Net;
using System.Net.Http.Json;
using LifeOS.Money.Api.Features.UserPreferences;
using LifeOS.Money.Tests.Infrastructure;

namespace LifeOS.Money.Tests.Features.UserPreferences;

public class PreferencesEndpointTests : IClassFixture<MoneyApiFactory>
{
    private readonly MoneyApiFactory _factory;

    public PreferencesEndpointTests(MoneyApiFactory factory) => _factory = factory;

    [Fact]
    public async Task Get_ReturnsDefaults_WhenNoPreferencesStored()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);

        var body = await client.GetFromJsonAsync<PreferencesResponse>("/api/preferences");

        Assert.NotNull(body);
        Assert.Equal(1, body!.MonthStartDay);
        Assert.Null(body.DisplayCurrency);
        Assert.False(body.OnboardingComplete);
    }

    [Fact]
    public async Task SetDisplayCurrency_PersistsAndCompletesOnboarding()
    {
        var client = _factory.CreateClientFor(TestUsers.Bob);

        var put = await client.PutAsJsonAsync(
            "/api/preferences/display-currency",
            new SetDisplayCurrencyRequest("EUR"));
        Assert.Equal(HttpStatusCode.OK, put.StatusCode);

        var put_body = await put.Content.ReadFromJsonAsync<PreferencesResponse>();
        Assert.Equal("EUR", put_body!.DisplayCurrency);
        Assert.True(put_body.OnboardingComplete);

        var get_body = await client.GetFromJsonAsync<PreferencesResponse>("/api/preferences");
        Assert.Equal("EUR", get_body!.DisplayCurrency);
        Assert.True(get_body.OnboardingComplete);
    }

    [Fact]
    public async Task SetMonthStartDay_PersistsAndIsReadBack()
    {
        var client = _factory.CreateClientForUser("prefs-month-user");

        var put = await client.PutAsJsonAsync(
            "/api/preferences/month-start-day",
            new SetMonthStartDayRequest(25));
        Assert.Equal(HttpStatusCode.OK, put.StatusCode);

        var body = await client.GetFromJsonAsync<PreferencesResponse>("/api/preferences");
        Assert.Equal(25, body!.MonthStartDay);
    }

    [Fact]
    public async Task SetDisplayCurrency_DoesNotResetMonthStartDay()
    {
        var client = _factory.CreateClientForUser("prefs-combined-user");

        await client.PutAsJsonAsync(
            "/api/preferences/month-start-day",
            new SetMonthStartDayRequest(15));
        await client.PutAsJsonAsync(
            "/api/preferences/display-currency",
            new SetDisplayCurrencyRequest("USD"));

        var body = await client.GetFromJsonAsync<PreferencesResponse>("/api/preferences");
        Assert.Equal(15, body!.MonthStartDay);
        Assert.Equal("USD", body.DisplayCurrency);
    }

    [Fact]
    public async Task SetDisplayCurrency_Returns400_WhenNotIso4217()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);

        var response = await client.PutAsJsonAsync(
            "/api/preferences/display-currency",
            new SetDisplayCurrencyRequest("eur"));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(32)]
    [InlineData(-1)]
    public async Task SetMonthStartDay_Returns400_WhenOutOfRange(int day)
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);

        var response = await client.PutAsJsonAsync(
            "/api/preferences/month-start-day",
            new SetMonthStartDayRequest(day));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Preferences_AreIsolatedPerOwner()
    {
        var alice = _factory.CreateClientForUser("prefs-isolation-alice");
        var bob = _factory.CreateClientForUser("prefs-isolation-bob");

        await alice.PutAsJsonAsync(
            "/api/preferences/display-currency",
            new SetDisplayCurrencyRequest("GBP"));

        var bobView = await bob.GetFromJsonAsync<PreferencesResponse>("/api/preferences");
        Assert.Null(bobView!.DisplayCurrency);
        Assert.False(bobView.OnboardingComplete);
    }
}

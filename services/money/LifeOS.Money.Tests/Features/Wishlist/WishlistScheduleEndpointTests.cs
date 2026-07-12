using System.Net.Http.Json;
using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Features.PlannedPurchases;
using LifeOS.Money.Api.Features.Wishlist;
using LifeOS.Money.Tests.Infrastructure;

namespace LifeOS.Money.Tests.Features.Wishlist;

public class WishlistScheduleEndpointTests : IClassFixture<MoneyApiFactory> {
    private readonly MoneyApiFactory _factory;

    public WishlistScheduleEndpointTests(MoneyApiFactory factory) => _factory = factory;

    private HttpClient NewUser() => _factory.CreateClientForUser(Guid.NewGuid().ToString());

    private static async Task<List<WishlistScheduleChipResponse>> GetSchedule(
        HttpClient client, Guid itemId, int fromYear, int fromMonth) {
        var res = await client.GetAsync(
            $"/api/wishlist/items/{itemId}/schedule?fromYear={fromYear}&fromMonth={fromMonth}");
        res.EnsureSuccessStatusCode();
        return (await res.Content.ReadFromJsonAsync<List<WishlistScheduleChipResponse>>())!;
    }

    [Fact]
    public async Task Schedule_GroupsByMonthAndSumsQuantity() {
        var client = NewUser();
        var item = Guid.NewGuid();

        await client.PostAsJsonAsync("/api/wishlist/items", new CreateWishlistItemRequest(
            item, "reusable", "Coffee beans", null, new CurrencyAmount(5m, "USD"), null, null, null, UnitDimension.Mass));

        // Two planned instances of 0.5 kg in October, both referencing the want.
        await client.PostAsJsonAsync("/api/months/2026/10/planned-purchases",
            new AddPlannedPurchaseRequest(Guid.NewGuid(), "USD", null,
                [new PlannedPurchaseLine(5m, null, null, item, 0.5m, UnitDimension.Mass)]));
        await client.PostAsJsonAsync("/api/months/2026/10/planned-purchases",
            new AddPlannedPurchaseRequest(Guid.NewGuid(), "USD", null,
                [new PlannedPurchaseLine(5m, null, null, item, 0.5m, UnitDimension.Mass)]));
        // A November instance in a different dimension (Pieces, ×2).
        await client.PostAsJsonAsync("/api/months/2026/11/planned-purchases",
            new AddPlannedPurchaseRequest(Guid.NewGuid(), "USD", null,
                [new PlannedPurchaseLine(8m, null, null, item, 2m, UnitDimension.Pieces)]));

        var chips = await GetSchedule(client, item, 2026, 10);

        // October's two Mass instances collapse to one chip (summed quantity 1.0).
        var oct = Assert.Single(chips, c => c.Month == 10);
        Assert.False(oct.Paid);
        Assert.Equal(UnitDimension.Mass, oct.UnitDimension);
        Assert.Equal(1.0m, oct.Quantity);

        // November is a separate Pieces chip.
        var nov = Assert.Single(chips, c => c.Month == 11);
        Assert.False(nov.Paid);
        Assert.Equal(UnitDimension.Pieces, nov.UnitDimension);
        Assert.Equal(2m, nov.Quantity);
    }

    [Fact]
    public async Task Schedule_MarksPaidAndTrimsBeforeWindow() {
        var client = NewUser();
        var item = Guid.NewGuid();
        await client.PostAsJsonAsync("/api/wishlist/items", new CreateWishlistItemRequest(
            item, "once", "Tires", null, new CurrencyAmount(400m, "USD"), null, null));

        // A March instance — before the fromMonth window, must not appear.
        await client.PostAsJsonAsync("/api/months/2026/3/planned-purchases",
            new AddPlannedPurchaseRequest(Guid.NewGuid(), "USD", null,
                [new PlannedPurchaseLine(400m, null, null, item, 1m, UnitDimension.Pieces)]));

        // A May instance that is then paid — appears as a paid chip. (May is a past
        // period, so recording the paying actual is allowed — ADR-0023 forbids actuals
        // only in future periods.)
        var may = Guid.NewGuid();
        await client.PostAsJsonAsync("/api/months/2026/5/planned-purchases",
            new AddPlannedPurchaseRequest(may, "USD", null,
                [new PlannedPurchaseLine(400m, null, null, item, 1m, UnitDimension.Pieces)]));
        var pay = await client.PostAsJsonAsync(
            $"/api/months/2026/5/planned-purchases/{may}/pay",
            new PayPlannedPurchaseRequest(Guid.NewGuid(), DateTimeOffset.Parse("2026-05-10T00:00:00Z"), null, null));
        pay.EnsureSuccessStatusCode();

        var chips = await GetSchedule(client, item, 2026, 5);

        var chip = Assert.Single(chips);
        Assert.Equal(5, chip.Month);
        Assert.True(chip.Paid);
        Assert.Equal(UnitDimension.Pieces, chip.UnitDimension);
        Assert.Equal(1m, chip.Quantity);
    }

    [Fact]
    public async Task Schedule_Returns404_OnUnknownItem() {
        var client = NewUser();
        var res = await client.GetAsync($"/api/wishlist/items/{Guid.NewGuid()}/schedule?fromYear=2026&fromMonth=1");
        Assert.Equal(System.Net.HttpStatusCode.NotFound, res.StatusCode);
    }
}

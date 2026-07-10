using System.Net.Http.Json;
using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Features.PlannedPurchases;
using LifeOS.Money.Api.Features.Recurring;
using LifeOS.Money.Api.Features.Wishlist;
using LifeOS.Money.Tests.Infrastructure;

namespace LifeOS.Money.Tests.Features.Wishlist;

/// The WishlistItemStatus projection (ADR-0034): a want's commitment state is derived
/// from AccountingPeriod + RecurringPayment events, never hand-edited.
public class WishlistStatusProjectionTests : IClassFixture<MoneyApiFactory> {
    private readonly MoneyApiFactory _factory;

    public WishlistStatusProjectionTests(MoneyApiFactory factory) => _factory = factory;

    private HttpClient NewUser() => _factory.CreateClientForUser(Guid.NewGuid().ToString());

    private static async Task<WishlistItemResponse> StatusOf(HttpClient client, Guid itemId) {
        var res = await client.GetAsync("/api/wishlist");
        res.EnsureSuccessStatusCode();
        var wishlist = (await res.Content.ReadFromJsonAsync<WishlistResponse>())!;
        return Assert.Single(wishlist.Items, x => x.Id == itemId);
    }

    private async Task<Guid> CreateWant(HttpClient client, WishlistRecurrence recurrence = WishlistRecurrence.Once) {
        var id = Guid.NewGuid();
        var res = await client.PostAsJsonAsync("/api/wishlist/items", new CreateWishlistItemRequest(
            id, recurrence, "Lens", null, new CurrencyAmount(800m, "USD"), null, null));
        res.EnsureSuccessStatusCode();
        return id;
    }

    [Fact]
    public async Task PlanningAWant_MakesItPlanned_WithPeriod() {
        var client = NewUser();
        var itemId = await CreateWant(client);

        await client.PostAsJsonAsync("/api/months/2026/8/planned-purchases",
            new AddPlannedPurchaseRequest(Guid.NewGuid(), "USD", "Lens",
                [new PlannedPurchaseLine(800m, null, "Lens", itemId)]));

        var status = await StatusOf(client, itemId);
        Assert.Equal(WishlistCommitment.Planned, status.Status);
        Assert.Equal(2026, status.PlannedYear);
        Assert.Equal(8, status.PlannedMonth);
    }

    [Fact]
    public async Task CancellingThePlan_ReturnsItToIdle() {
        var client = NewUser();
        var itemId = await CreateWant(client);
        var entryId = Guid.NewGuid();
        await client.PostAsJsonAsync("/api/months/2026/8/planned-purchases",
            new AddPlannedPurchaseRequest(entryId, "USD", "Lens",
                [new PlannedPurchaseLine(800m, null, "Lens", itemId)]));

        var cancel = await client.DeleteAsync($"/api/months/2026/8/planned-purchases/{entryId}");
        cancel.EnsureSuccessStatusCode();

        Assert.Equal(WishlistCommitment.Idle, (await StatusOf(client, itemId)).Status);
    }

    [Fact]
    public async Task PayingThePlannedPurchase_MakesItBought_EvenWhenAmountAdjusted() {
        var client = NewUser();
        var itemId = await CreateWant(client);
        var entryId = Guid.NewGuid();
        // A past period, so paying (an actual) is allowed — future periods are planning-only
        // (ADR-0023).
        await client.PostAsJsonAsync("/api/months/2026/5/planned-purchases",
            new AddPlannedPurchaseRequest(entryId, "USD", "Lens",
                [new PlannedPurchaseLine(800m, null, "Lens", itemId)]));

        // Pay with an adjusted amount → the settling flow drops the wishlist line ref, so
        // Bought must be derived by the PlannedEntryId join, not the flow line.
        var pay = await client.PostAsJsonAsync($"/api/months/2026/5/planned-purchases/{entryId}/pay",
            new PayPlannedPurchaseRequest(Guid.NewGuid(), DateTimeOffset.Parse("2026-05-10T00:00:00Z"), 760m, null));
        pay.EnsureSuccessStatusCode();

        var status = await StatusOf(client, itemId);
        Assert.Equal(WishlistCommitment.Bought, status.Status);
        Assert.Equal(new DateOnly(2026, 5, 10), status.BoughtDate);
    }

    [Fact]
    public async Task FinancingViaPaymentPlan_MakesItFinanced_AndCancelReturnsToIdle() {
        var client = NewUser();
        var itemId = await CreateWant(client);
        var planId = Guid.NewGuid();

        var create = await client.PostAsJsonAsync("/api/recurring", new CreateRecurringRequest(
            planId, "Board game pledge", "out", "USD", null, null, "materialized",
            Rule: null,
            EstimateLines: null,
            Items: [new PlanItemRequest("Kickstarter all-in", 300m, null, itemId)],
            ScheduleLines: [
                new ScheduleLineRequest(Guid.NewGuid(), new DateOnly(2026, 9, 1), 150m),
                new ScheduleLineRequest(Guid.NewGuid(), new DateOnly(2026, 10, 1), 150m),
            ]));
        create.EnsureSuccessStatusCode();

        var financed = await StatusOf(client, itemId);
        Assert.Equal(WishlistCommitment.Financed, financed.Status);
        Assert.Equal(planId, financed.PlanId);

        var cancel = await client.PostAsync($"/api/recurring/{planId}/cancel", content: null);
        cancel.EnsureSuccessStatusCode();

        Assert.Equal(WishlistCommitment.Idle, (await StatusOf(client, itemId)).Status);
    }

    [Fact]
    public async Task ReusableWant_CanBePlanned_AndStaysAWant() {
        var client = NewUser();
        var itemId = await CreateWant(client, WishlistRecurrence.Reusable);

        await client.PostAsJsonAsync("/api/months/2026/8/planned-purchases",
            new AddPlannedPurchaseRequest(Guid.NewGuid(), "USD", "Coffee",
                [new PlannedPurchaseLine(5m, null, "Coffee", itemId)]));

        var status = await StatusOf(client, itemId);
        Assert.Equal(WishlistCommitment.Planned, status.Status);
        // Reusable is preserved so the client keeps it in the tray.
        Assert.Equal(WishlistRecurrence.Reusable, status.Recurrence);
    }
}

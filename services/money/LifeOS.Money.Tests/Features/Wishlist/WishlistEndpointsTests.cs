using System.Net;
using System.Net.Http.Json;
using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Features.Wishlist;
using LifeOS.Money.Tests.Infrastructure;

namespace LifeOS.Money.Tests.Features.Wishlist;

public class WishlistEndpointsTests : IClassFixture<MoneyApiFactory> {
    private readonly MoneyApiFactory _factory;

    public WishlistEndpointsTests(MoneyApiFactory factory) => _factory = factory;

    // A fresh random owner per test → isolated wishlist state on the shared DB.
    private HttpClient NewUser() => _factory.CreateClientForUser(Guid.NewGuid().ToString());

    private static async Task<WishlistResponse> GetWishlist(HttpClient client) {
        var res = await client.GetAsync("/api/wishlist");
        res.EnsureSuccessStatusCode();
        return (await res.Content.ReadFromJsonAsync<WishlistResponse>())!;
    }

    [Fact]
    public async Task Create_Returns201_AndReadsBackIdleWithRecurrence() {
        var client = NewUser();
        var id = Guid.NewGuid();

        var res = await client.PostAsJsonAsync("/api/wishlist/items", new CreateWishlistItemRequest(
            id, "reusable", "Coffee", null, new CurrencyAmount(5m, "USD"), null, null));

        Assert.Equal(HttpStatusCode.Created, res.StatusCode);
        var wishlist = await GetWishlist(client);
        var item = Assert.Single(wishlist.Items, x => x.Id == id);
        Assert.Equal("Coffee", item.Name);
        Assert.Equal("reusable", item.Recurrence);
        Assert.Equal("idle", item.Status);
        Assert.Equal(5m, item.Estimate!.Amount);
    }

    [Fact]
    public async Task Create_AllowsNullEstimate() {
        var client = NewUser();
        var id = Guid.NewGuid();

        var res = await client.PostAsJsonAsync("/api/wishlist/items", new CreateWishlistItemRequest(
            id, "once", "Mystery gift", null, null, null, null));

        res.EnsureSuccessStatusCode();
        var wishlist = await GetWishlist(client);
        Assert.Null(Assert.Single(wishlist.Items, x => x.Id == id).Estimate);
    }

    [Fact]
    public async Task Create_IsIdempotent_OnSameId() {
        var client = NewUser();
        var id = Guid.NewGuid();
        var request = new CreateWishlistItemRequest(
            id, "once", "Fridge", null, null, null, null);

        var first = await client.PostAsJsonAsync("/api/wishlist/items", request);
        var second = await client.PostAsJsonAsync("/api/wishlist/items", request);

        Assert.Equal(HttpStatusCode.Created, first.StatusCode);
        Assert.Equal(HttpStatusCode.OK, second.StatusCode);
        var wishlist = await GetWishlist(client);
        Assert.Single(wishlist.Items, x => x.Id == id);
    }

    [Fact]
    public async Task Edit_ReplacesDesireFields() {
        var client = NewUser();
        var id = Guid.NewGuid();
        await client.PostAsJsonAsync("/api/wishlist/items", new CreateWishlistItemRequest(
            id, "once", "Tires", null, new CurrencyAmount(400m, "USD"), null, null));

        var edit = await client.PutAsJsonAsync($"/api/wishlist/items/{id}", new EditWishlistItemRequest(
            "once", "Winter tires", "studded", new CurrencyAmount(520m, "USD"), null, null));
        edit.EnsureSuccessStatusCode();

        var item = Assert.Single((await GetWishlist(client)).Items, x => x.Id == id);
        Assert.Equal("Winter tires", item.Name);
        Assert.Equal("studded", item.Notes);
        Assert.Equal(520m, item.Estimate!.Amount);
    }

    [Fact]
    public async Task Edit_Returns404_OnUnknownItem() {
        var client = NewUser();
        var res = await client.PutAsJsonAsync($"/api/wishlist/items/{Guid.NewGuid()}", new EditWishlistItemRequest(
            "once", "x", null, null, null, null));
        Assert.Equal(HttpStatusCode.NotFound, res.StatusCode);
    }

    [Fact]
    public async Task Delete_RemovesItem_AndIsIdempotent() {
        var client = NewUser();
        var id = Guid.NewGuid();
        await client.PostAsJsonAsync("/api/wishlist/items", new CreateWishlistItemRequest(
            id, "once", "Impulse", null, null, null, null));

        var first = await client.DeleteAsync($"/api/wishlist/items/{id}");
        var second = await client.DeleteAsync($"/api/wishlist/items/{id}");

        Assert.Equal(HttpStatusCode.NoContent, first.StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, second.StatusCode);
        Assert.DoesNotContain((await GetWishlist(client)).Items, x => x.Id == id);
    }

    [Fact]
    public async Task Package_Create_Group_AndDelete_Ungroups() {
        var client = NewUser();
        var packageId = Guid.NewGuid();
        var itemId = Guid.NewGuid();
        await client.PostAsJsonAsync("/api/wishlist/packages", new CreatePackageRequest(packageId, "All-in pledge"));
        await client.PostAsJsonAsync("/api/wishlist/items", new CreateWishlistItemRequest(
            itemId, "once", "Base game", null, null, packageId, null));

        var wishlist = await GetWishlist(client);
        Assert.Single(wishlist.Packages, x => x.Id == packageId);
        Assert.Equal(packageId, Assert.Single(wishlist.Items, x => x.Id == itemId).PackageId);

        var del = await client.DeleteAsync($"/api/wishlist/packages/{packageId}");
        del.EnsureSuccessStatusCode();

        var after = await GetWishlist(client);
        Assert.DoesNotContain(after.Packages, x => x.Id == packageId);
        // The item survives, ungrouped.
        Assert.Null(Assert.Single(after.Items, x => x.Id == itemId).PackageId);
    }

    [Fact]
    public async Task Wishlist_IsOwnerScoped() {
        var alice = _factory.CreateClientForUser(Guid.NewGuid().ToString());
        var bob = _factory.CreateClientForUser(Guid.NewGuid().ToString());
        await alice.PostAsJsonAsync("/api/wishlist/items", new CreateWishlistItemRequest(
            Guid.NewGuid(), "once", "Alice only", null, null, null, null));

        Assert.Empty((await GetWishlist(bob)).Items);
    }

    [Fact]
    public async Task Create_AndEdit_CarryCategoryAndDefaultUnitDimension() {
        var client = NewUser();
        var id = Guid.NewGuid();
        var category = Guid.NewGuid();

        var res = await client.PostAsJsonAsync("/api/wishlist/items", new CreateWishlistItemRequest(
            id, "reusable", "Coffee beans", null, new CurrencyAmount(5m, "USD"), null, null, category, UnitDimension.Mass));
        res.EnsureSuccessStatusCode();

        var item = Assert.Single((await GetWishlist(client)).Items, x => x.Id == id);
        Assert.Equal(category, item.CategoryId);
        Assert.Equal(UnitDimension.Mass, item.DefaultUnitDimension);

        // Edit clears both (null) — a full replace of the desire fields.
        var edit = await client.PutAsJsonAsync($"/api/wishlist/items/{id}", new EditWishlistItemRequest(
            "reusable", "Coffee beans", null, new CurrencyAmount(5m, "USD"), null, null, null, null));
        edit.EnsureSuccessStatusCode();

        var after = Assert.Single((await GetWishlist(client)).Items, x => x.Id == id);
        Assert.Null(after.CategoryId);
        Assert.Null(after.DefaultUnitDimension);
    }
}

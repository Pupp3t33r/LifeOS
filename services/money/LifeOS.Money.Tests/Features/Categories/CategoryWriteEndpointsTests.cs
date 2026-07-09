using System.Net;
using System.Net.Http.Json;
using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Features.Categories;
using LifeOS.Money.Tests.Infrastructure;

namespace LifeOS.Money.Tests.Features.Categories;

public class CategoryWriteEndpointsTests : IClassFixture<MoneyApiFactory> {
    private readonly MoneyApiFactory _factory;

    public CategoryWriteEndpointsTests(MoneyApiFactory factory) => _factory = factory;

    // A fresh random owner per test → isolated category state on the shared DB.
    private HttpClient NewUser() => _factory.CreateClientForUser(Guid.NewGuid().ToString());

    private static async Task<List<CategoryResponse>> GetCategories(
        HttpClient client, bool includeArchived = false) {
        var res = await client.GetAsync($"/api/categories?includeArchived={includeArchived}");
        res.EnsureSuccessStatusCode();
        return (await res.Content.ReadFromJsonAsync<List<CategoryResponse>>())!;
    }

    [Fact]
    public async Task Create_Returns201_AndAppearsInOverlay() {
        var client = NewUser();
        var id = Guid.NewGuid();

        var res = await client.PostAsJsonAsync("/api/categories", new CreateCategoryRequest(id, "Groceries"));

        Assert.Equal(HttpStatusCode.Created, res.StatusCode);
        var body = await res.Content.ReadFromJsonAsync<CategoryResponse>();
        Assert.Equal(id, body!.Id);
        Assert.Equal("Groceries", body.Name);
        Assert.False(body.System);
        Assert.False(body.Archived);

        var all = await GetCategories(client);
        Assert.Contains(all, x => x.Id == id && x.Name == "Groceries");
        // The three system categories are always present in the overlay.
        Assert.Equal(SystemCategories.All.Count, all.Count(x => x.System));
    }

    [Fact]
    public async Task Create_TrimsName() {
        var client = NewUser();
        var id = Guid.NewGuid();

        var res = await client.PostAsJsonAsync("/api/categories", new CreateCategoryRequest(id, "  Coffee  "));

        var body = await res.Content.ReadFromJsonAsync<CategoryResponse>();
        Assert.Equal("Coffee", body!.Name);
    }

    [Fact]
    public async Task Create_IsIdempotent_OnSameIdAndName() {
        var client = NewUser();
        var id = Guid.NewGuid();
        var request = new CreateCategoryRequest(id, "Rent");

        var first = await client.PostAsJsonAsync("/api/categories", request);
        var second = await client.PostAsJsonAsync("/api/categories", request);

        Assert.Equal(HttpStatusCode.Created, first.StatusCode);
        Assert.Equal(HttpStatusCode.OK, second.StatusCode);
        var all = await GetCategories(client);
        Assert.Single(all, x => x.Id == id);
    }

    [Theory]
    [InlineData("Transport")]
    [InlineData("transport")]
    [InlineData("  TRANSPORT ")]
    public async Task Create_Returns422_WhenNameTaken_CaseInsensitive(string clashing) {
        var client = NewUser();
        await client.PostAsJsonAsync("/api/categories", new CreateCategoryRequest(Guid.NewGuid(), "Transport"));

        var conflict = await client.PostAsJsonAsync(
            "/api/categories", new CreateCategoryRequest(Guid.NewGuid(), clashing));

        Assert.Equal(HttpStatusCode.UnprocessableEntity, conflict.StatusCode);
    }

    [Fact]
    public async Task Create_Returns422_WhenNameCollidesWithSystemCategory() {
        var client = NewUser();

        var conflict = await client.PostAsJsonAsync(
            "/api/categories", new CreateCategoryRequest(Guid.NewGuid(), "Books"));

        Assert.Equal(HttpStatusCode.UnprocessableEntity, conflict.StatusCode);
    }

    [Fact]
    public async Task Create_Returns400_WhenNameBlank() {
        var client = NewUser();

        var res = await client.PostAsJsonAsync("/api/categories", new CreateCategoryRequest(Guid.NewGuid(), "   "));

        Assert.Equal(HttpStatusCode.BadRequest, res.StatusCode);
    }

    [Fact]
    public async Task Create_Returns404_WhenIdOwnedByAnotherUser() {
        var alice = NewUser();
        var bob = NewUser();
        var id = Guid.NewGuid();
        await alice.PostAsJsonAsync("/api/categories", new CreateCategoryRequest(id, "Owned"));

        var byBob = await bob.PostAsJsonAsync("/api/categories", new CreateCategoryRequest(id, "Owned"));

        Assert.Equal(HttpStatusCode.NotFound, byBob.StatusCode);
    }

    [Fact]
    public async Task Rename_Returns200_AndUpdatesOverlay() {
        var client = NewUser();
        var id = Guid.NewGuid();
        await client.PostAsJsonAsync("/api/categories", new CreateCategoryRequest(id, "Food"));

        var res = await client.PatchAsJsonAsync($"/api/categories/{id}", new RenameCategoryRequest("Eating out"));

        Assert.Equal(HttpStatusCode.OK, res.StatusCode);
        var all = await GetCategories(client);
        Assert.Contains(all, x => x.Id == id && x.Name == "Eating out");
        Assert.DoesNotContain(all, x => x.Name == "Food");
    }

    [Fact]
    public async Task Rename_Returns422_WhenTargetNameTaken() {
        var client = NewUser();
        var keep = Guid.NewGuid();
        var move = Guid.NewGuid();
        await client.PostAsJsonAsync("/api/categories", new CreateCategoryRequest(keep, "Groceries"));
        await client.PostAsJsonAsync("/api/categories", new CreateCategoryRequest(move, "Snacks"));

        var res = await client.PatchAsJsonAsync($"/api/categories/{move}", new RenameCategoryRequest("groceries"));

        Assert.Equal(HttpStatusCode.UnprocessableEntity, res.StatusCode);
    }

    [Fact]
    public async Task Rename_ToSameName_IsNoOp_Returns200() {
        var client = NewUser();
        var id = Guid.NewGuid();
        await client.PostAsJsonAsync("/api/categories", new CreateCategoryRequest(id, "Rent"));

        var res = await client.PatchAsJsonAsync($"/api/categories/{id}", new RenameCategoryRequest("Rent"));

        Assert.Equal(HttpStatusCode.OK, res.StatusCode);
    }

    [Fact]
    public async Task Rename_Returns403_ForSystemCategory() {
        var client = NewUser();

        var res = await client.PatchAsJsonAsync(
            $"/api/categories/{SystemCategories.Books.Id}", new RenameCategoryRequest("My Books"));

        Assert.Equal(HttpStatusCode.Forbidden, res.StatusCode);
    }

    [Fact]
    public async Task Archive_HidesFromDefault_ButShowsWithIncludeArchived() {
        var client = NewUser();
        var id = Guid.NewGuid();
        await client.PostAsJsonAsync("/api/categories", new CreateCategoryRequest(id, "Holiday fund"));

        var archive = await client.PostAsync($"/api/categories/{id}/archive", null);
        Assert.Equal(HttpStatusCode.OK, archive.StatusCode);

        Assert.DoesNotContain(await GetCategories(client), x => x.Id == id);
        var withArchived = await GetCategories(client, includeArchived: true);
        Assert.Contains(withArchived, x => x.Id == id && x.Archived);
    }

    [Fact]
    public async Task Unarchive_RestoresToDefault() {
        var client = NewUser();
        var id = Guid.NewGuid();
        await client.PostAsJsonAsync("/api/categories", new CreateCategoryRequest(id, "Gaming gear"));
        await client.PostAsync($"/api/categories/{id}/archive", null);

        var unarchive = await client.PostAsync($"/api/categories/{id}/unarchive", null);
        Assert.Equal(HttpStatusCode.OK, unarchive.StatusCode);

        Assert.Contains(await GetCategories(client), x => x.Id == id && !x.Archived);
    }

    [Fact]
    public async Task ArchivedName_StaysReserved_BlocksNewCreate() {
        var client = NewUser();
        var archived = Guid.NewGuid();
        await client.PostAsJsonAsync("/api/categories", new CreateCategoryRequest(archived, "Books stash"));
        await client.PostAsync($"/api/categories/{archived}/archive", null);

        var reuse = await client.PostAsJsonAsync(
            "/api/categories", new CreateCategoryRequest(Guid.NewGuid(), "Books stash"));

        Assert.Equal(HttpStatusCode.UnprocessableEntity, reuse.StatusCode);
    }

    [Fact]
    public async Task RenamingArchived_FreesTheName_ForReintroduction() {
        var client = NewUser();
        var archived = Guid.NewGuid();
        await client.PostAsJsonAsync("/api/categories", new CreateCategoryRequest(archived, "Reading"));
        await client.PostAsync($"/api/categories/{archived}/archive", null);

        // "Reading" is now held only by an archived category → still reserved.
        var blocked = await client.PostAsJsonAsync(
            "/api/categories", new CreateCategoryRequest(Guid.NewGuid(), "Reading"));
        Assert.Equal(HttpStatusCode.UnprocessableEntity, blocked.StatusCode);

        // Rename the archived holder to free the name, then reintroduce it fresh.
        await client.PatchAsJsonAsync($"/api/categories/{archived}", new RenameCategoryRequest("Reading (old)"));
        var reintroduced = await client.PostAsJsonAsync(
            "/api/categories", new CreateCategoryRequest(Guid.NewGuid(), "Reading"));

        Assert.Equal(HttpStatusCode.Created, reintroduced.StatusCode);
    }
}

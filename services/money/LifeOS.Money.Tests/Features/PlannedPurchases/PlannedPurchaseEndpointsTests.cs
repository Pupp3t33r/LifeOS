using System.Net;
using System.Net.Http.Json;
using LifeOS.Money.Api.Features.Periods;
using LifeOS.Money.Api.Features.PlannedPurchases;
using LifeOS.Money.Tests.Infrastructure;

namespace LifeOS.Money.Tests.Features.PlannedPurchases;

public class PlannedPurchaseEndpointsTests : IClassFixture<MoneyApiFactory>
{
    private readonly MoneyApiFactory _factory;

    public PlannedPurchaseEndpointsTests(MoneyApiFactory factory) => _factory = factory;

    [Fact]
    public async Task Add_Returns200_SignsTotalNegative_AndListsAsPlanned()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);
        var entryId = Guid.NewGuid();

        var response = await client.PostAsJsonAsync(
            "/api/months/2026/8/planned-purchases",
            new AddPlannedPurchaseRequest(entryId, "USD", "New lens",
                [new PlannedPurchaseLine(800m, null, null)]));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<PlannedPurchaseWriteResponse>();
        Assert.Equal(-800m, body!.Total.Amount);
        Assert.Equal("USD", body.Total.Currency);

        var list = await GetPlanned(client, 2026, 8);
        var item = Assert.Single(list, x => x.EntryId == entryId);
        Assert.Equal("planned", item.Status);
        Assert.Equal(-800m, item.Total.Amount);
        Assert.Null(item.PaidTotal);
    }

    [Fact]
    public async Task Add_Returns409_OnDuplicateEntryId()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);
        var entryId = Guid.NewGuid();

        var first = await client.PostAsJsonAsync(
            "/api/months/2026/9/planned-purchases",
            new AddPlannedPurchaseRequest(entryId, "USD", "first",
                [new PlannedPurchaseLine(100m, null, null)]));
        first.EnsureSuccessStatusCode();

        var second = await client.PostAsJsonAsync(
            "/api/months/2026/9/planned-purchases",
            new AddPlannedPurchaseRequest(entryId, "USD", "dup",
                [new PlannedPurchaseLine(100m, null, null)]));

        Assert.Equal(HttpStatusCode.Conflict, second.StatusCode);
    }

    [Fact]
    public async Task Add_Returns400_OnNoLines()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);

        var response = await client.PostAsJsonAsync(
            "/api/months/2026/9/planned-purchases",
            new AddPlannedPurchaseRequest(Guid.NewGuid(), "USD", null, []));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Edit_ReplacesLines_ReflectedInList()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);
        var entryId = Guid.NewGuid();

        await client.PostAsJsonAsync(
            "/api/months/2026/10/planned-purchases",
            new AddPlannedPurchaseRequest(entryId, "USD", "Tripod",
                [new PlannedPurchaseLine(120m, null, null)]));

        var edit = await client.PutAsJsonAsync(
            $"/api/months/2026/10/planned-purchases/{entryId}",
            new EditPlannedPurchaseRequest("USD", "Tripod (deluxe)",
                [new PlannedPurchaseLine(160m, null, null)]));
        edit.EnsureSuccessStatusCode();

        var list = await GetPlanned(client, 2026, 10);
        var item = Assert.Single(list, x => x.EntryId == entryId);
        Assert.Equal(-160m, item.Total.Amount);
        Assert.Equal("Tripod (deluxe)", item.Description);
    }

    [Fact]
    public async Task Edit_Returns404_OnUnknownEntry()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);

        var response = await client.PutAsJsonAsync(
            $"/api/months/2026/10/planned-purchases/{Guid.NewGuid()}",
            new EditPlannedPurchaseRequest("USD", null,
                [new PlannedPurchaseLine(10m, null, null)]));

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task Cancel_RemovesFromList()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);
        var entryId = Guid.NewGuid();

        await client.PostAsJsonAsync(
            "/api/months/2026/11/planned-purchases",
            new AddPlannedPurchaseRequest(entryId, "USD", "Impulse buy",
                [new PlannedPurchaseLine(45m, null, null)]));

        var cancel = await client.DeleteAsync($"/api/months/2026/11/planned-purchases/{entryId}");
        cancel.EnsureSuccessStatusCode();

        var list = await GetPlanned(client, 2026, 11);
        Assert.DoesNotContain(list, x => x.EntryId == entryId);
    }

    [Fact]
    public async Task Cancel_Returns404_OnUnknownEntry()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);

        var response = await client.DeleteAsync($"/api/months/2026/11/planned-purchases/{Guid.NewGuid()}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task Edit_Returns409_AfterCancel()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);
        var entryId = Guid.NewGuid();

        await client.PostAsJsonAsync(
            "/api/months/2026/12/planned-purchases",
            new AddPlannedPurchaseRequest(entryId, "USD", null,
                [new PlannedPurchaseLine(45m, null, null)]));
        await client.DeleteAsync($"/api/months/2026/12/planned-purchases/{entryId}");

        var edit = await client.PutAsJsonAsync(
            $"/api/months/2026/12/planned-purchases/{entryId}",
            new EditPlannedPurchaseRequest("USD", null,
                [new PlannedPurchaseLine(50m, null, null)]));

        Assert.Equal(HttpStatusCode.Conflict, edit.StatusCode);
    }

    [Fact]
    public async Task Pay_MarksPlannedPaid_AndRecordsFlow()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);
        var plannedId = Guid.NewGuid();

        await client.PostAsJsonAsync(
            "/api/months/2026/5/planned-purchases",
            new AddPlannedPurchaseRequest(plannedId, "USD", "Monitor",
                [new PlannedPurchaseLine(300m, null, null)]));

        var pay = await client.PostAsJsonAsync(
            $"/api/months/2026/5/planned-purchases/{plannedId}/pay",
            new PayPlannedPurchaseRequest(Guid.NewGuid(), DateTimeOffset.Parse("2026-05-10T00:00:00Z"), null, null));
        pay.EnsureSuccessStatusCode();
        var payBody = await pay.Content.ReadFromJsonAsync<PayPlannedPurchaseResponse>();
        Assert.Equal(-300m, payBody!.Total.Amount);

        // Planned purchase now reads as paid, with the settling flow's actuals.
        var list = await GetPlanned(client, 2026, 5);
        var item = Assert.Single(list, x => x.EntryId == plannedId);
        Assert.Equal("paid", item.Status);
        Assert.Equal(-300m, item.PaidTotal!.Amount);

        // And it landed in the flow ledger as a real actual.
        var flows = await (await client.GetAsync("/api/months/2026/5"))
            .Content.ReadFromJsonAsync<PeriodFlowsResponse>();
        Assert.Contains(flows!.Entries, x => x.Total.Amount == -300m && x.Description == "Monitor");
    }

    [Fact]
    public async Task Pay_WithAdjustedAmount_RecordsActualPaid()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);
        var plannedId = Guid.NewGuid();

        await client.PostAsJsonAsync(
            "/api/months/2026/6/planned-purchases",
            new AddPlannedPurchaseRequest(plannedId, "USD", "Desk",
                [new PlannedPurchaseLine(500m, null, null)]));

        var pay = await client.PostAsJsonAsync(
            $"/api/months/2026/6/planned-purchases/{plannedId}/pay",
            new PayPlannedPurchaseRequest(Guid.NewGuid(), DateTimeOffset.Parse("2026-06-10T00:00:00Z"), 465m, null));
        pay.EnsureSuccessStatusCode();

        var list = await GetPlanned(client, 2026, 6);
        var item = Assert.Single(list, x => x.EntryId == plannedId);
        Assert.Equal("paid", item.Status);
        Assert.Equal(-500m, item.Total.Amount);       // the plan estimate is unchanged
        Assert.Equal(-465m, item.PaidTotal!.Amount);   // what was actually paid
    }

    [Fact]
    public async Task Pay_Returns409_OnSecondPay()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);
        var plannedId = Guid.NewGuid();

        await client.PostAsJsonAsync(
            "/api/months/2026/4/planned-purchases",
            new AddPlannedPurchaseRequest(plannedId, "USD", "Chair",
                [new PlannedPurchaseLine(200m, null, null)]));
        var first = await client.PostAsJsonAsync(
            $"/api/months/2026/4/planned-purchases/{plannedId}/pay",
            new PayPlannedPurchaseRequest(Guid.NewGuid(), DateTimeOffset.Parse("2026-04-10T00:00:00Z"), null, null));
        first.EnsureSuccessStatusCode();

        var second = await client.PostAsJsonAsync(
            $"/api/months/2026/4/planned-purchases/{plannedId}/pay",
            new PayPlannedPurchaseRequest(Guid.NewGuid(), DateTimeOffset.Parse("2026-04-11T00:00:00Z"), null, null));

        Assert.Equal(HttpStatusCode.Conflict, second.StatusCode);
    }

    [Fact]
    public async Task Pay_Returns404_OnUnknownPlannedPurchase()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);

        var response = await client.PostAsJsonAsync(
            $"/api/months/2026/3/planned-purchases/{Guid.NewGuid()}/pay",
            new PayPlannedPurchaseRequest(Guid.NewGuid(), DateTimeOffset.Parse("2026-03-10T00:00:00Z"), null, null));

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task List_IsOwnerScoped()
    {
        var alice = _factory.CreateClientFor(TestUsers.Alice);
        var bob = _factory.CreateClientFor(TestUsers.Bob);

        await alice.PostAsJsonAsync(
            "/api/months/2027/1/planned-purchases",
            new AddPlannedPurchaseRequest(Guid.NewGuid(), "USD", "Alice only",
                [new PlannedPurchaseLine(10m, null, null)]));

        var list = await GetPlanned(bob, 2027, 1);
        Assert.Empty(list);
    }

    private static async Task<IReadOnlyList<PlannedPurchaseResponse>> GetPlanned(
        HttpClient client, int year, int month)
    {
        var response = await client.GetAsync($"/api/months/{year}/{month}/planned-purchases");
        response.EnsureSuccessStatusCode();
        return (await response.Content.ReadFromJsonAsync<List<PlannedPurchaseResponse>>())!;
    }
}

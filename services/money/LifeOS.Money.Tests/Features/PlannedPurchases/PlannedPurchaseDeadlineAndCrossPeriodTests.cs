using System.Net.Http.Json;
using LifeOS.Money.Api.Features.PlannedPurchases;
using LifeOS.Money.Tests.Infrastructure;

namespace LifeOS.Money.Tests.Features.PlannedPurchases;

/// The ADR-0034 additions to planned purchases: an optional deadline, and a cross-period
/// read for the Plan List / Board.
public class PlannedPurchaseDeadlineAndCrossPeriodTests : IClassFixture<MoneyApiFactory> {
    private readonly MoneyApiFactory _factory;

    public PlannedPurchaseDeadlineAndCrossPeriodTests(MoneyApiFactory factory) => _factory = factory;

    private HttpClient NewUser() => _factory.CreateClientForUser(Guid.NewGuid().ToString());

    [Fact]
    public async Task Add_WithDeadline_ReadsBackOnThePeriodList() {
        var client = NewUser();
        var entryId = Guid.NewGuid();
        var deadline = new DateOnly(2026, 8, 20);

        await client.PostAsJsonAsync("/api/months/2026/8/planned-purchases",
            new AddPlannedPurchaseRequest(entryId, "USD", "Gift",
                [new PlannedPurchaseLine(50m, null, "Gift")], deadline));

        var list = await client.GetFromJsonAsync<List<PlannedPurchaseResponse>>(
            "/api/months/2026/8/planned-purchases");
        Assert.Equal(deadline, Assert.Single(list!, x => x.EntryId == entryId).Deadline);
    }

    [Fact]
    public async Task CrossPeriodList_ReturnsAllPeriods_WithForwardFilter() {
        var client = NewUser();

        await client.PostAsJsonAsync("/api/months/2026/8/planned-purchases",
            new AddPlannedPurchaseRequest(Guid.NewGuid(), "USD", "Aug buy",
                [new PlannedPurchaseLine(50m, null, null)]));
        await client.PostAsJsonAsync("/api/months/2026/10/planned-purchases",
            new AddPlannedPurchaseRequest(Guid.NewGuid(), "USD", "Oct buy",
                [new PlannedPurchaseLine(70m, null, null)]));

        var all = await client.GetFromJsonAsync<List<PeriodPlannedPurchaseResponse>>("/api/planned-purchases");
        Assert.Equal(2, all!.Count);
        Assert.Contains(all, x => x is { Year: 2026, Month: 8 });
        Assert.Contains(all, x => x is { Year: 2026, Month: 10 });

        // Forward filter drops the earlier period.
        var fromSept = await client.GetFromJsonAsync<List<PeriodPlannedPurchaseResponse>>(
            "/api/planned-purchases?fromYear=2026&fromMonth=9");
        Assert.Single(fromSept!);
        Assert.Equal(10, fromSept![0].Month);
    }
}

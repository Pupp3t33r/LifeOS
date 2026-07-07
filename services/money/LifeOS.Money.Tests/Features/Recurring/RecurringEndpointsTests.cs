using System.Net;
using System.Net.Http.Json;
using LifeOS.Money.Api.Domain.Recurring;
using LifeOS.Money.Api.Features.Recurring;
using LifeOS.Money.Tests.Infrastructure;
using Xunit;

namespace LifeOS.Money.Tests.Features.Recurring;

public class RecurringEndpointsTests : IClassFixture<MoneyApiFactory>
{
    private readonly MoneyApiFactory _factory;

    public RecurringEndpointsTests(MoneyApiFactory factory) => _factory = factory;

    private static CreateRecurringRequest LiveRent(Guid id) => new(
        id, "Rent", "out", "USD", null, null, "live",
        new MonthlyRule(new DateOnly(2026, 1, 1), new NeverEnds(), 1, [new OnDayOfMonth(1)]),
        [new RecurringLineRequest(1000m, null, "Rent")],
        null,
        null);

    // A plan: one priceless item, paid off in N monthly $200 payments (Σ payments = total).
    private static CreateRecurringRequest MaterializedInstallments(Guid id, params Guid[] lineIds) => new(
        id, "Laptop", "out", "USD", null, null, "materialized", null, null,
        [new PlanItemRequest("Laptop", null, null, null)],
        lineIds.Select((lineId, i) => new ScheduleLineRequest(
            lineId, new DateOnly(2026, 2 + i, 1), 200m)).ToList());

    [Fact]
    public async Task CreateLive_ReturnsRuleEstimateAndDerivedAmount()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);

        var response = await client.PostAsJsonAsync("/api/recurring", LiveRent(Guid.NewGuid()));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<RecurringResponse>();
        Assert.Equal("live", body!.Mode);
        Assert.Equal("active", body.Status);
        Assert.IsType<MonthlyRule>(body.Rule);
        Assert.Equal(-1000m, body.EstimatedAmount!.Amount);   // signed: an 'out'
        Assert.Equal(-1000m, Assert.Single(body.EstimateLines).Amount.Amount);
        Assert.Empty(body.Items);
    }

    [Fact]
    public async Task CreateMaterialized_StoresItemsAndBarePayments()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);

        var response = await client.PostAsJsonAsync(
            "/api/recurring", MaterializedInstallments(Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid()));

        var body = await response.Content.ReadFromJsonAsync<RecurringResponse>();
        Assert.Equal("materialized", body!.Mode);
        Assert.Null(body.Rule);
        Assert.Equal("Laptop", Assert.Single(body.Items).Description);   // priceless contents
        Assert.Equal(2, body.ScheduleLines.Count);
        Assert.All(body.ScheduleLines, x => Assert.Equal(-200m, x.Amount.Amount));
    }

    [Fact]
    public async Task CreateMaterialized_ItemsNeedNotBalancePayments_Ok()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);

        // Two priceless items (reference values only), one $170 payment — no balance
        // requirement (ADR-0029); the plan total is the payments.
        var request = new CreateRecurringRequest(
            Guid.NewGuid(), "Pre-order", "out", "USD", null, null, "materialized", null, null,
            [new PlanItemRequest("Base game", 90m, null, null),
             new PlanItemRequest("Addon", 81m, null, null)],
            [new ScheduleLineRequest(Guid.NewGuid(), new DateOnly(2026, 2, 1), 170m)]);

        var response = await client.PostAsJsonAsync("/api/recurring", request);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<RecurringResponse>();
        Assert.Equal(2, body!.Items.Count);
        Assert.Equal(-170m, Assert.Single(body.ScheduleLines).Amount.Amount);
    }

    [Fact]
    public async Task Create_DuplicateId_Returns409()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);
        var id = Guid.NewGuid();

        await client.PostAsJsonAsync("/api/recurring", LiveRent(id));
        var second = await client.PostAsJsonAsync("/api/recurring", LiveRent(id));

        Assert.Equal(HttpStatusCode.Conflict, second.StatusCode);
    }

    [Fact]
    public async Task CreateLive_WithoutRule_Returns400()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);
        var bad = LiveRent(Guid.NewGuid()) with { Rule = null };

        var response = await client.PostAsJsonAsync("/api/recurring", bad);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task CreateLive_WithBadInterval_Returns400()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);
        var bad = LiveRent(Guid.NewGuid()) with
        {
            Rule = new DailyRule(new DateOnly(2026, 1, 1), new NeverEnds(), 0),
        };

        var response = await client.PostAsJsonAsync("/api/recurring", bad);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Get_IsOwnerScoped()
    {
        var alice = _factory.CreateClientFor(TestUsers.Alice);
        var bob = _factory.CreateClientFor(TestUsers.Bob);
        var id = Guid.NewGuid();
        await alice.PostAsJsonAsync("/api/recurring", LiveRent(id));

        Assert.Equal(HttpStatusCode.OK, (await alice.GetAsync($"/api/recurring/{id}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await bob.GetAsync($"/api/recurring/{id}")).StatusCode);
    }

    [Fact]
    public async Task Occurrences_Live_AreComputedInWindow()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);
        var id = Guid.NewGuid();
        await client.PostAsJsonAsync("/api/recurring", LiveRent(id));

        var occurrences = await client.GetFromJsonAsync<List<OccurrenceResponse>>(
            $"/api/recurring/{id}/occurrences?from=2026-01-01&to=2026-03-31");

        Assert.Equal(3, occurrences!.Count);
        Assert.Equal(new DateOnly(2026, 1, 1), occurrences[0].DueDate);
        Assert.Equal("2026-01-01", occurrences[0].OccurrenceRef);
        Assert.Equal(-1000m, occurrences[0].ExpectedAmount.Amount);
        Assert.Equal(new DateOnly(2026, 3, 1), occurrences[2].DueDate);
    }

    [Fact]
    public async Task Occurrences_Materialized_ListPaymentsInWindow()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);
        var id = Guid.NewGuid();
        var l1 = Guid.NewGuid();
        var l2 = Guid.NewGuid();
        await client.PostAsJsonAsync("/api/recurring", MaterializedInstallments(id, l1, l2));

        var occurrences = await client.GetFromJsonAsync<List<OccurrenceResponse>>(
            $"/api/recurring/{id}/occurrences?from=2026-02-01&to=2026-02-28");

        var only = Assert.Single(occurrences!);
        Assert.Equal(l1.ToString(), only.OccurrenceRef);
        Assert.Equal(new DateOnly(2026, 2, 1), only.DueDate);
        Assert.Equal(-200m, only.ExpectedAmount.Amount);
        // Its single reference line = the $200 this payment schedules (ADR-0029).
        Assert.Equal(-200m, Assert.Single(only.Lines).Amount.Amount);
    }

    [Fact]
    public async Task ChangeRule_OnLive_UpdatesRule_OnMaterialized_Conflicts()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);
        var liveId = Guid.NewGuid();
        await client.PostAsJsonAsync("/api/recurring", LiveRent(liveId));

        var newRule = new MonthlyRule(new DateOnly(2026, 1, 15), new NeverEnds(), 1, [new OnDayOfMonth(15)]);
        var change = await client.PutAsJsonAsync(
            $"/api/recurring/{liveId}/rule", new ChangeRuleRequest(newRule));
        Assert.Equal(HttpStatusCode.OK, change.StatusCode);
        var body = await change.Content.ReadFromJsonAsync<RecurringResponse>();
        var monthly = Assert.IsType<MonthlyRule>(body!.Rule);
        Assert.Equal(new OnDayOfMonth(15), Assert.Single(monthly.Days));

        var matId = Guid.NewGuid();
        await client.PostAsJsonAsync("/api/recurring", MaterializedInstallments(matId, Guid.NewGuid()));
        var conflict = await client.PutAsJsonAsync(
            $"/api/recurring/{matId}/rule", new ChangeRuleRequest(newRule));
        Assert.Equal(HttpStatusCode.Conflict, conflict.StatusCode);
    }

    [Fact]
    public async Task Cancel_IsTerminal_ThenEditConflicts()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);
        var id = Guid.NewGuid();
        await client.PostAsJsonAsync("/api/recurring", LiveRent(id));

        var cancel = await client.PostAsync($"/api/recurring/{id}/cancel", null);
        var body = await cancel.Content.ReadFromJsonAsync<RecurringResponse>();
        Assert.Equal("cancelled", body!.Status);

        var edit = await client.PutAsJsonAsync(
            $"/api/recurring/{id}", new EditRecurringRequest("New name", null, null));
        Assert.Equal(HttpStatusCode.Conflict, edit.StatusCode);
    }
}

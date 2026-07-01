using System.Net;
using System.Net.Http.Json;
using LifeOS.Money.Api.Domain.Recurring;
using LifeOS.Money.Api.Features.Recurring;
using LifeOS.Money.Tests.Infrastructure;
using Xunit;

namespace LifeOS.Money.Tests.Features.Recurring;

public class RecurringOccurrenceLifecycleTests : IClassFixture<MoneyApiFactory>
{
    private readonly MoneyApiFactory _factory;

    public RecurringOccurrenceLifecycleTests(MoneyApiFactory factory) => _factory = factory;

    private static CreateRecurringRequest LiveRent(Guid id) => new(
        id, "Rent", "out", "USD", null, null, "live",
        new MonthlyRule(new DateOnly(2026, 1, 1), new NeverEnds(), 1, [new OnDayOfMonth(1)]),
        [new RecurringLineRequest(1000m, null, "Rent")],
        null);

    private async Task<List<OccurrenceResponse>> Occurrences(HttpClient client, Guid id) =>
        (await client.GetFromJsonAsync<List<OccurrenceResponse>>(
            $"/api/recurring/{id}/occurrences?from=2026-01-01&to=2026-03-31"))!;

    [Fact]
    public async Task Confirm_MarksOccurrencePaid_WithActuals()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);
        var id = Guid.NewGuid();
        await client.PostAsJsonAsync("/api/recurring", LiveRent(id));

        var confirm = await client.PostAsJsonAsync($"/api/recurring/{id}/occurrences/confirm",
            new ConfirmOccurrenceRequest(Guid.NewGuid(), "2026-01-01",
                DateTimeOffset.Parse("2026-01-01T00:00:00Z"), null, null));
        Assert.Equal(HttpStatusCode.OK, confirm.StatusCode);

        var occurrences = await Occurrences(client, id);
        var jan = occurrences.Single(x => x.OccurrenceRef == "2026-01-01");
        Assert.Equal("paid", jan.Status);
        Assert.Equal(-1000m, jan.ActualAmount!.Amount);
        Assert.Equal(new DateOnly(2026, 1, 1), jan.PaidOn);
        // Others remain projected.
        Assert.Equal("projected", occurrences.Single(x => x.OccurrenceRef == "2026-02-01").Status);
    }

    [Fact]
    public async Task Confirm_WithLineOverride_RecordsActualDifferentFromExpected()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);
        var id = Guid.NewGuid();
        await client.PostAsJsonAsync("/api/recurring", LiveRent(id));

        await client.PostAsJsonAsync($"/api/recurring/{id}/occurrences/confirm",
            new ConfirmOccurrenceRequest(Guid.NewGuid(), "2026-03-01",
                DateTimeOffset.Parse("2026-03-01T00:00:00Z"),
                [new RecurringLineRequest(950m, null, "Rent (discounted)")], null));

        var mar = (await Occurrences(client, id)).Single(x => x.OccurrenceRef == "2026-03-01");
        Assert.Equal("paid", mar.Status);
        Assert.Equal(-950m, mar.ActualAmount!.Amount);      // actual
        Assert.Equal(-1000m, mar.ExpectedAmount.Amount);    // schedule unchanged
    }

    [Fact]
    public async Task Skip_MarksOccurrenceSkipped()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);
        var id = Guid.NewGuid();
        await client.PostAsJsonAsync("/api/recurring", LiveRent(id));

        var skip = await client.PostAsJsonAsync($"/api/recurring/{id}/occurrences/skip",
            new SkipOccurrenceRequest("2026-02-01"));
        Assert.Equal(HttpStatusCode.OK, skip.StatusCode);

        var feb = (await Occurrences(client, id)).Single(x => x.OccurrenceRef == "2026-02-01");
        Assert.Equal("skipped", feb.Status);
    }

    [Fact]
    public async Task DoubleConfirm_SameOccurrence_Returns409()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);
        var id = Guid.NewGuid();
        await client.PostAsJsonAsync("/api/recurring", LiveRent(id));

        var request = new ConfirmOccurrenceRequest(Guid.NewGuid(), "2026-01-01",
            DateTimeOffset.Parse("2026-01-01T00:00:00Z"), null, null);
        await client.PostAsJsonAsync($"/api/recurring/{id}/occurrences/confirm", request);

        // A fresh EntryId, same occurrence → occurrence-level idempotency (409).
        var second = await client.PostAsJsonAsync($"/api/recurring/{id}/occurrences/confirm",
            request with { EntryId = Guid.NewGuid() });
        Assert.Equal(HttpStatusCode.Conflict, second.StatusCode);
    }

    [Fact]
    public async Task Confirm_UnknownOccurrenceRef_Returns404()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);
        var id = Guid.NewGuid();
        await client.PostAsJsonAsync("/api/recurring", LiveRent(id));

        var response = await client.PostAsJsonAsync($"/api/recurring/{id}/occurrences/confirm",
            new ConfirmOccurrenceRequest(Guid.NewGuid(), "not-a-date",
                DateTimeOffset.Parse("2026-01-01T00:00:00Z"), null, null));

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task Materialized_ConfirmScheduleLine_MarksPaid()
    {
        var client = _factory.CreateClientFor(TestUsers.Alice);
        var id = Guid.NewGuid();
        var lineId = Guid.NewGuid();
        await client.PostAsJsonAsync("/api/recurring", new CreateRecurringRequest(
            id, "Laptop", "out", "USD", null, null, "materialized", null, null,
            [new ScheduleLineRequest(lineId, new DateOnly(2026, 2, 1), [new RecurringLineRequest(200m, null, null)])]));

        await client.PostAsJsonAsync($"/api/recurring/{id}/occurrences/confirm",
            new ConfirmOccurrenceRequest(Guid.NewGuid(), lineId.ToString(),
                DateTimeOffset.Parse("2026-02-01T00:00:00Z"), null, null));

        var occurrences = await client.GetFromJsonAsync<List<OccurrenceResponse>>(
            $"/api/recurring/{id}/occurrences?from=2026-01-01&to=2026-12-31");
        var line = occurrences!.Single(x => x.OccurrenceRef == lineId.ToString());
        Assert.Equal("paid", line.Status);
        Assert.Equal(-200m, line.ActualAmount!.Amount);
    }
}

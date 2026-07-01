using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Domain.Events;
using Xunit;

namespace LifeOS.Money.Tests.Domain;

public class AccountingPeriodOccurrenceTests
{
    private static readonly DateTimeOffset When = DateTimeOffset.Parse("2026-01-01T00:00:00Z");

    private static IReadOnlyList<Line> Lines(decimal amount) =>
        [new Line(null, new CurrencyAmount(amount, "USD"), null)];

    private static AccountingPeriod PeriodWith(FlowRecorded flow)
    {
        var period = new AccountingPeriod();
        period.Apply(flow);
        return period;
    }

    [Fact]
    public void Confirm_MarksOccurrenceResolved_AndCarriesBackRef()
    {
        var period = new AccountingPeriod();
        var occurrence = new RecurringReference(Guid.NewGuid(), "2026-01-01");

        var flow = period.RecordFlow(
            Guid.NewGuid(), "owner", 2026, 1, Guid.NewGuid(), FlowDirection.Out,
            Lines(-1000m), When, When, null, occurrence);

        Assert.Equal(occurrence, flow.Recurring);
        period.Apply(flow);
        Assert.True(period.IsOccurrenceResolved(occurrence));
    }

    [Fact]
    public void DoubleConfirm_SameOccurrence_Throws()
    {
        var occurrence = new RecurringReference(Guid.NewGuid(), "2026-01-01");
        var period = PeriodWith(new FlowRecorded(
            Guid.NewGuid(), "owner", 2026, 1, Guid.NewGuid(), FlowDirection.Out,
            Lines(-1000m), When, When, null, occurrence));

        Assert.Throws<DuplicateOccurrenceException>(() => period.RecordFlow(
            Guid.NewGuid(), "owner", 2026, 1, Guid.NewGuid(), FlowDirection.Out,
            Lines(-1000m), When, When, null, occurrence));
    }

    [Fact]
    public void Skip_ThenConfirm_SameOccurrence_Throws()
    {
        var period = new AccountingPeriod();
        var occurrence = new RecurringReference(Guid.NewGuid(), "2026-01-01");

        var skipped = period.SkipOccurrence(Guid.NewGuid(), "owner", 2026, 1, occurrence, When);
        period.Apply(skipped);
        Assert.True(period.IsOccurrenceResolved(occurrence));

        Assert.Throws<DuplicateOccurrenceException>(() => period.SkipOccurrence(
            Guid.NewGuid(), "owner", 2026, 1, occurrence, When));
        Assert.Throws<DuplicateOccurrenceException>(() => period.RecordFlow(
            Guid.NewGuid(), "owner", 2026, 1, Guid.NewGuid(), FlowDirection.Out,
            Lines(-1000m), When, When, null, occurrence));
    }

    [Fact]
    public void AdHocFlow_WithoutBackRef_DoesNotResolveAnything()
    {
        var period = new AccountingPeriod();
        var flow = period.RecordFlow(
            Guid.NewGuid(), "owner", 2026, 1, Guid.NewGuid(), FlowDirection.Out,
            Lines(-50m), When, When, "Coffee");

        Assert.Null(flow.Recurring);
        period.Apply(flow);
        Assert.Empty(period.ResolvedOccurrences);
    }
}

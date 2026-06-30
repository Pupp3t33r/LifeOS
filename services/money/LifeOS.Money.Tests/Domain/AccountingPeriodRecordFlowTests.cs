using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Domain.Events;

namespace LifeOS.Money.Tests.Domain;

public class AccountingPeriodRecordFlowTests
{
    private static Line MakeLine(decimal amount, string currency = "USD") =>
        new(null, new CurrencyAmount(amount, currency), null);

    private static FlowRecorded Record(AccountingPeriod period, Guid entryId, params Line[] lines) =>
        period.RecordFlow(
            Guid.NewGuid(),
            "owner-1",
            2026,
            6,
            entryId,
            FlowDirection.Out,
            lines,
            DateTimeOffset.UtcNow,
            DateTimeOffset.UtcNow,
            "Costco run");

    [Fact]
    public void RejectsEmptyLines()
    {
        var period = new AccountingPeriod();
        Assert.Throws<ArgumentException>(() => Record(period, Guid.NewGuid()));
    }

    [Fact]
    public void RejectsZeroAmountLine()
    {
        var period = new AccountingPeriod();
        Assert.Throws<ArgumentException>(() => Record(period, Guid.NewGuid(), MakeLine(0m)));
    }

    [Fact]
    public void RejectsMixedCurrency()
    {
        var period = new AccountingPeriod();
        Assert.Throws<InvalidOperationException>(() =>
            Record(period, Guid.NewGuid(), MakeLine(-10m, "USD"), MakeLine(-5m, "EUR")));
    }

    [Fact]
    public void RejectsDuplicateEntryId()
    {
        var period = new AccountingPeriod();
        var entryId = Guid.NewGuid();
        period.Apply(Record(period, entryId, MakeLine(-10m)));

        Assert.Throws<DuplicateFlowException>(() => Record(period, entryId, MakeLine(-10m)));
    }

    [Fact]
    public void ReturnsFlowRecorded_WithExpectedPayload()
    {
        var period = new AccountingPeriod();
        var entryId = Guid.NewGuid();

        var recorded = Record(period, entryId, MakeLine(-62m), MakeLine(-34m));

        Assert.Equal(entryId, recorded.EntryId);
        Assert.Equal("owner-1", recorded.OwnerId);
        Assert.Equal(FlowDirection.Out, recorded.Direction);
        Assert.Equal(2, recorded.Lines.Count);
        Assert.Equal("Costco run", recorded.Description);
    }
}

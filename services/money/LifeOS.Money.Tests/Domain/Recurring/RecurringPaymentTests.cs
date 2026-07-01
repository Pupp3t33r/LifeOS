using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Domain.Events;
using LifeOS.Money.Api.Domain.Recurring;
using Xunit;

namespace LifeOS.Money.Tests.Domain.Recurring;

public class RecurringPaymentTests
{
    private static readonly DateTimeOffset Now = DateTimeOffset.Parse("2026-07-01T00:00:00Z");

    private static Line Out(decimal amount, string currency = "USD") =>
        new(null, new CurrencyAmount(-amount, currency), null);

    private static RecurringPayment Rehydrate(RecurringPaymentCreated created)
    {
        var agg = new RecurringPayment();
        agg.Apply(created);
        return agg;
    }

    private static RecurringPaymentCreated NewLive() => RecurringPayment.CreateLive(
        Guid.NewGuid(), "owner-1", "Rent", FlowDirection.Out, "USD", null, null,
        new MonthlyRule(new DateOnly(2026, 1, 1), new NeverEnds(), 1, [new OnDayOfMonth(1)]),
        [Out(1000m)], Now);

    private static RecurringPaymentCreated NewMaterialized(params ScheduleLine[] lines) =>
        RecurringPayment.CreateMaterialized(
            Guid.NewGuid(), "owner-1", "Laptop installments", FlowDirection.Out, "USD", null, null,
            lines, Now);

    [Fact]
    public void CreateLive_SetsRuleAndEstimate()
    {
        var agg = Rehydrate(NewLive());

        Assert.Equal(ScheduleMode.Live, agg.Mode);
        Assert.IsType<MonthlyRule>(agg.Rule);
        Assert.Equal(-1000m, Assert.Single(agg.EstimateLines).Amount.Amount);
        Assert.Empty(agg.ScheduleLines);
        Assert.Equal(RecurringStatus.Active, agg.Status);
    }

    [Fact]
    public void CreateMaterialized_StoresLines()
    {
        var line = new ScheduleLine(Guid.NewGuid(), new DateOnly(2026, 2, 1), [Out(200m)]);
        var agg = Rehydrate(NewMaterialized(line));

        Assert.Equal(ScheduleMode.Materialized, agg.Mode);
        Assert.Null(agg.Rule);
        Assert.Equal(-200m, Assert.Single(agg.ScheduleLines).Total);
    }

    [Fact]
    public void ChangeRule_OnLive_EmitsRuleChanged()
    {
        var agg = Rehydrate(NewLive());
        var newRule = new MonthlyRule(new DateOnly(2026, 1, 15), new NeverEnds(), 1, [new OnDayOfMonth(15)]);

        var evt = agg.ChangeRule(newRule, Now);
        agg.Apply(evt);

        Assert.Equal(newRule, agg.Rule);
    }

    [Fact]
    public void ChangeRule_OnMaterialized_Throws()
    {
        var agg = Rehydrate(NewMaterialized());
        var rule = new DailyRule(new DateOnly(2026, 1, 1), new NeverEnds(), 1);

        Assert.Throws<InvalidOperationException>(() => agg.ChangeRule(rule, Now));
    }

    [Fact]
    public void ScheduleLines_AddEditRemove_MutateList()
    {
        var agg = Rehydrate(NewMaterialized());
        var id = Guid.NewGuid();

        agg.Apply(agg.AddScheduleLine(new ScheduleLine(id, new DateOnly(2026, 3, 1), [Out(100m)])));
        Assert.Equal(-100m, Assert.Single(agg.ScheduleLines).Total);

        agg.Apply(agg.EditScheduleLine(new ScheduleLine(id, new DateOnly(2026, 3, 5), [Out(150m)])));
        Assert.Equal(-150m, agg.ScheduleLines.Single().Total);
        Assert.Equal(new DateOnly(2026, 3, 5), agg.ScheduleLines.Single().DueDate);

        agg.Apply(agg.RemoveScheduleLine(id));
        Assert.Empty(agg.ScheduleLines);
    }

    [Fact]
    public void AddScheduleLine_DuplicateId_Throws()
    {
        var agg = Rehydrate(NewMaterialized());
        var id = Guid.NewGuid();
        agg.Apply(agg.AddScheduleLine(new ScheduleLine(id, new DateOnly(2026, 3, 1), [Out(100m)])));

        Assert.Throws<ArgumentException>(() =>
            agg.AddScheduleLine(new ScheduleLine(id, new DateOnly(2026, 4, 1), [Out(100m)])));
    }

    [Fact]
    public void Cancel_IsTerminal_BlocksFurtherEdits()
    {
        var agg = Rehydrate(NewLive());

        agg.Apply(agg.Cancel(Now));
        Assert.Equal(RecurringStatus.Cancelled, agg.Status);

        Assert.Throws<InvalidOperationException>(() => agg.EditHeader("New name", null, null));
        Assert.Throws<InvalidOperationException>(() => agg.Cancel(Now));
    }

    [Fact]
    public void Create_RejectsBadInput()
    {
        // Zero amount line.
        Assert.Throws<ArgumentException>(() => RecurringPayment.CreateLive(
            Guid.NewGuid(), "o", "X", FlowDirection.Out, "USD", null, null,
            new DailyRule(new DateOnly(2026, 1, 1), new NeverEnds(), 1),
            [new Line(null, new CurrencyAmount(0m, "USD"), null)], Now));

        // Currency mismatch.
        Assert.Throws<InvalidOperationException>(() => RecurringPayment.CreateLive(
            Guid.NewGuid(), "o", "X", FlowDirection.Out, "USD", null, null,
            new DailyRule(new DateOnly(2026, 1, 1), new NeverEnds(), 1),
            [Out(10m, "EUR")], Now));

        // Interval 0 (generator guard fires via eager check).
        Assert.Throws<ArgumentOutOfRangeException>(() => RecurringPayment.CreateLive(
            Guid.NewGuid(), "o", "X", FlowDirection.Out, "USD", null, null,
            new DailyRule(new DateOnly(2026, 1, 1), new NeverEnds(), 0),
            [Out(10m)], Now));
    }
}

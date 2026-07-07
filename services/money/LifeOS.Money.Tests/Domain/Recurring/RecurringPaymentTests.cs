using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Domain.Events;
using LifeOS.Money.Api.Domain.Recurring;
using Xunit;

namespace LifeOS.Money.Tests.Domain.Recurring;

public class RecurringPaymentTests
{
    private static readonly DateTimeOffset Now = DateTimeOffset.Parse("2026-07-01T00:00:00Z");

    private static Line Out(decimal amount, string currency = "USD", Guid? category = null) =>
        new(null, new CurrencyAmount(-amount, currency), category);

    // A priceless plan item (ADR-0029) — optional reference value, no cost.
    private static PlanItem Item(
        string? description = null, decimal? reference = null, string currency = "USD", Guid? category = null) =>
        new(description, reference is { } r ? new CurrencyAmount(r, currency) : null, category, null);

    private static ScheduleLine Pay(Guid lineId, DateOnly due, decimal amount, string currency = "USD") =>
        new(lineId, due, new CurrencyAmount(-amount, currency));

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

    // A minimal plan: one priceless item, paid off in one $200 payment (the plan total).
    private static RecurringPaymentCreated NewMaterialized() => RecurringPayment.CreateMaterialized(
        Guid.NewGuid(), "owner-1", "Laptop", FlowDirection.Out, "USD", null, null,
        [Item("Laptop")], [Pay(Guid.NewGuid(), new DateOnly(2026, 2, 1), 200m)], Now);

    [Fact]
    public void CreateLive_SetsRuleAndEstimate()
    {
        var agg = Rehydrate(NewLive());

        Assert.Equal(ScheduleMode.Live, agg.Mode);
        Assert.IsType<MonthlyRule>(agg.Rule);
        Assert.Equal(-1000m, Assert.Single(agg.EstimateLines).Amount.Amount);
        Assert.Empty(agg.Items);
        Assert.Empty(agg.ScheduleLines);
        Assert.Equal(RecurringStatus.Active, agg.Status);
    }

    [Fact]
    public void CreateMaterialized_StoresPricelessItemsAndBareSchedule()
    {
        var agg = Rehydrate(NewMaterialized());

        Assert.Equal(ScheduleMode.Materialized, agg.Mode);
        Assert.Null(agg.Rule);
        Assert.Empty(agg.EstimateLines);
        Assert.Equal("Laptop", Assert.Single(agg.Items).Description);
        Assert.Equal(-200m, Assert.Single(agg.ScheduleLines).Amount.Amount);
    }

    [Fact]
    public void CreateMaterialized_ItemsAndPaymentsNeedNotBalance()
    {
        // No balance invariant (ADR-0029): two priceless items, one $170 payment is fine.
        var agg = Rehydrate(RecurringPayment.CreateMaterialized(
            Guid.NewGuid(), "owner-1", "Pre-order", FlowDirection.Out, "USD", null, null,
            [Item("Base game", reference: 90m), Item("Addon", reference: 81m)],
            [Pay(Guid.NewGuid(), new DateOnly(2026, 2, 1), 170m)],
            Now));

        Assert.Equal(2, agg.Items.Count);
        Assert.Equal(-170m, Assert.Single(agg.ScheduleLines).Amount.Amount);
    }

    [Fact]
    public void CreateMaterialized_NoItems_Throws()
    {
        Assert.Throws<ArgumentException>(() => RecurringPayment.CreateMaterialized(
            Guid.NewGuid(), "owner-1", "Plan", FlowDirection.Out, "USD", null, null,
            [], [Pay(Guid.NewGuid(), new DateOnly(2026, 2, 1), 200m)], Now));
    }

    [Fact]
    public void CreateMaterialized_NoPayments_Throws()
    {
        Assert.Throws<ArgumentException>(() => RecurringPayment.CreateMaterialized(
            Guid.NewGuid(), "owner-1", "Pre-order", FlowDirection.Out, "USD", null, null,
            [Item("Thing")], [], Now));
    }

    [Fact]
    public void CreateMaterialized_DuplicateLineId_Throws()
    {
        var id = Guid.NewGuid();
        Assert.Throws<ArgumentException>(() => RecurringPayment.CreateMaterialized(
            Guid.NewGuid(), "owner-1", "Plan", FlowDirection.Out, "USD", null, null,
            [Item("Thing")],
            [Pay(id, new DateOnly(2026, 2, 1), 100m), Pay(id, new DateOnly(2026, 3, 1), 100m)],
            Now));
    }

    [Fact]
    public void ReferenceLineForOccurrence_IsScheduledAmountUnderPlanCategory()
    {
        // A plan payment records one reference line (ADR-0029): the scheduled amount,
        // the plan's category, no per-item breakdown.
        var games = Guid.NewGuid();
        var p1 = Guid.NewGuid();
        var agg = Rehydrate(RecurringPayment.CreateMaterialized(
            Guid.NewGuid(), "owner-1", "Board game pledge", FlowDirection.Out, "USD", games, null,
            [Item("Base game"), Item("Addon", reference: 36m)],
            [Pay(p1, new DateOnly(2026, 2, 1), 57m),
             Pay(Guid.NewGuid(), new DateOnly(2026, 3, 1), 57m)],
            Now));

        var line = agg.ReferenceLineForOccurrence(p1);

        Assert.Equal(-57m, line.Amount.Amount);
        Assert.Equal(games, line.CategoryId);
        Assert.Null(line.Description);
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
    public void Cancel_RecordsRefundDisposition_AndIsTerminal()
    {
        var agg = Rehydrate(NewMaterialized());

        var cancelled = agg.Cancel(refunded: true, Now);
        Assert.True(cancelled.Refunded);
        agg.Apply(cancelled);
        Assert.Equal(RecurringStatus.Cancelled, agg.Status);

        Assert.Throws<InvalidOperationException>(() => agg.EditHeader("New name", null, null));
        Assert.Throws<InvalidOperationException>(() => agg.Cancel(false, Now));
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

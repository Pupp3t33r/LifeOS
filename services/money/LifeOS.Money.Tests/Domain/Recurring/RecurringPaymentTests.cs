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

    // A minimal balanced plan: one $200 item financed by one $200 payment.
    private static RecurringPaymentCreated NewMaterialized() => RecurringPayment.CreateMaterialized(
        Guid.NewGuid(), "owner-1", "Laptop", FlowDirection.Out, "USD", null, null,
        [Out(200m)], [Pay(Guid.NewGuid(), new DateOnly(2026, 2, 1), 200m)], Now);

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
    public void CreateMaterialized_StoresItemsAndBareSchedule()
    {
        var agg = Rehydrate(NewMaterialized());

        Assert.Equal(ScheduleMode.Materialized, agg.Mode);
        Assert.Null(agg.Rule);
        Assert.Empty(agg.EstimateLines);
        Assert.Equal(-200m, Assert.Single(agg.Items).Amount.Amount);
        Assert.Equal(-200m, Assert.Single(agg.ScheduleLines).Amount.Amount);
    }

    [Fact]
    public void CreateMaterialized_Unbalanced_Throws()
    {
        // Items total -171, payments total -170 → rejected.
        Assert.Throws<InvalidOperationException>(() => RecurringPayment.CreateMaterialized(
            Guid.NewGuid(), "owner-1", "Pre-order", FlowDirection.Out, "USD", null, null,
            [Out(90m), Out(81m)],
            [Pay(Guid.NewGuid(), new DateOnly(2026, 2, 1), 85m),
             Pay(Guid.NewGuid(), new DateOnly(2026, 3, 1), 85m)],
            Now));
    }

    [Fact]
    public void CreateMaterialized_NoPayments_Throws()
    {
        Assert.Throws<ArgumentException>(() => RecurringPayment.CreateMaterialized(
            Guid.NewGuid(), "owner-1", "Pre-order", FlowDirection.Out, "USD", null, null,
            [Out(200m)], [], Now));
    }

    [Fact]
    public void CreateMaterialized_DuplicateLineId_Throws()
    {
        var id = Guid.NewGuid();
        Assert.Throws<ArgumentException>(() => RecurringPayment.CreateMaterialized(
            Guid.NewGuid(), "owner-1", "Plan", FlowDirection.Out, "USD", null, null,
            [Out(200m)],
            [Pay(id, new DateOnly(2026, 2, 1), 100m), Pay(id, new DateOnly(2026, 3, 1), 100m)],
            Now));
    }

    [Fact]
    public void SliceForOccurrence_EvenPlan_SplitsItemsProportionally()
    {
        // The board-game pledge: base -90 + three addons (-36/-27/-18) = -171, in 3×-57.
        var games = Guid.NewGuid();
        var p1 = Guid.NewGuid();
        var p2 = Guid.NewGuid();
        var p3 = Guid.NewGuid();
        var agg = Rehydrate(RecurringPayment.CreateMaterialized(
            Guid.NewGuid(), "owner-1", "Board game pledge", FlowDirection.Out, "USD", null, null,
            [Out(90m, category: games), Out(36m, category: games), Out(27m, category: games), Out(18m, category: games)],
            [Pay(p1, new DateOnly(2026, 2, 1), 57m),
             Pay(p2, new DateOnly(2026, 3, 1), 57m),
             Pay(p3, new DateOnly(2026, 4, 1), 57m)],
            Now));

        var slice = agg.SliceForOccurrence(p1);

        // Each item scaled by 57/171 = 1/3: 30 / 12 / 9 / 6, summing to the payment.
        Assert.Equal(new[] { -30m, -12m, -9m, -6m }, slice.Select(x => x.Amount.Amount));
        Assert.All(slice, x => Assert.Equal(games, x.CategoryId));
        Assert.Equal(-57m, slice.Sum(x => x.Amount.Amount));
    }

    [Fact]
    public void SliceForOccurrence_RoundingCase_EachPaymentSumsExact_AndCumulativeExact()
    {
        // Three $1.00 items over three $1.00 payments: 1/3 splits force cent rounding.
        var ids = new[] { Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid() };
        var agg = Rehydrate(RecurringPayment.CreateMaterialized(
            Guid.NewGuid(), "owner-1", "Trio", FlowDirection.Out, "USD", null, null,
            [Out(1m), Out(1m), Out(1m)],
            [Pay(ids[0], new DateOnly(2026, 2, 1), 1m),
             Pay(ids[1], new DateOnly(2026, 3, 1), 1m),
             Pay(ids[2], new DateOnly(2026, 4, 1), 1m)],
            Now));

        var cumulative = new decimal[3];
        foreach (var id in ids)
        {
            var slice = agg.SliceForOccurrence(id);
            Assert.Equal(-1.00m, slice.Sum(x => x.Amount.Amount));   // each payment balances
            for (var j = 0; j < 3; j++)
            {
                cumulative[j] += slice[j].Amount.Amount;
            }
        }

        Assert.All(cumulative, x => Assert.Equal(-1.00m, x));   // every item fully allocated
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

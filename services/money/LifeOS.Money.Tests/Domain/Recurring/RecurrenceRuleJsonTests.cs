using System.Text.Json;
using LifeOS.Money.Api.Domain.Recurring;
using Xunit;

namespace LifeOS.Money.Tests.Domain.Recurring;

/// The recurrence rule is serialized as a `kind`-discriminated union (ADR-0017) that
/// the Dart client mirrors. These lock the discriminator values and the polymorphic
/// round-trip through the abstract base — the exact contract the client depends on.
public class RecurrenceRuleJsonTests
{
    private static readonly JsonSerializerOptions Options = new(JsonSerializerDefaults.Web);

    [Fact]
    public void MonthlyRule_SerializesWithKindDiscriminator()
    {
        RecurrenceRule rule = new MonthlyRule(
            new DateOnly(2026, 1, 1), new NeverEnds(), 1, [new OnDayOfMonth(1), new LastDayOfMonth()]);

        var json = JsonSerializer.Serialize(rule, Options);

        Assert.Contains("\"kind\":\"monthly\"", json);
        Assert.Contains("\"kind\":\"never\"", json);   // nested RecurrenceEnd union
        Assert.Contains("\"kind\":\"dayOfMonth\"", json); // nested MonthDayAnchor union
        Assert.Contains("\"kind\":\"lastDay\"", json);
    }

    [Fact]
    public void RoundTrips_ThroughAbstractBase_PreservingSubtype()
    {
        RecurrenceRule original = new WeeklyRule(
            new DateOnly(2026, 1, 2), new EndsAfter(10), 2, [DayOfWeek.Friday]);

        var json = JsonSerializer.Serialize(original, Options);
        var back = JsonSerializer.Deserialize<RecurrenceRule>(json, Options);

        var weekly = Assert.IsType<WeeklyRule>(back);
        Assert.Equal(2, weekly.IntervalWeeks);
        Assert.Equal([DayOfWeek.Friday], weekly.Weekdays);
        var end = Assert.IsType<EndsAfter>(weekly.End);
        Assert.Equal(10, end.Count);
    }

    [Fact]
    public void RoundTrips_AllRuleKinds()
    {
        RecurrenceRule[] rules =
        [
            new DailyRule(new DateOnly(2026, 1, 1), new NeverEnds(), 20),
            new WeeklyRule(new DateOnly(2026, 1, 1), new EndsOnDate(new DateOnly(2027, 1, 1)), 1, [DayOfWeek.Monday]),
            new MonthlyRule(new DateOnly(2026, 1, 1), new NeverEnds(), 3, [new OnDayOfMonth(15)]),
            new YearlyRule(new DateOnly(2026, 1, 1), new EndsAfter(5), 1, [new AnnualDate(6, 30)]),
        ];

        foreach (var rule in rules)
        {
            var json = JsonSerializer.Serialize(rule, Options);
            var back = JsonSerializer.Deserialize<RecurrenceRule>(json, Options);
            // Records with IReadOnlyList members use reference equality, so compare
            // round-trip fidelity at the JSON level (and the concrete subtype).
            Assert.Equal(rule.GetType(), back!.GetType());
            Assert.Equal(json, JsonSerializer.Serialize(back, Options));
        }
    }
}

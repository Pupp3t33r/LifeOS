using LifeOS.Money.Api.Domain.Fx;
using LifeOS.Money.Api.Fx;
using Xunit;

namespace LifeOS.Money.Tests.Fx;

public class BelarusbankRateSourceTests
{
    // A trimmed kurs_cards element: direct SELL/BUY pairs plus a cross-pair that must
    // be ignored, and the timestamp the date is read from.
    private const string SampleJson = """
    [
      {
        "kurs_date_time": "2026-07-01 09:00:00",
        "USDCARD_in": "2.9000",
        "USDCARD_out": "2.9500",
        "EURCARD_in": "3.2700",
        "EURCARD_out": "3.3400",
        "RUBCARD_in": "3.2500",
        "RUBCARD_out": "3.5800",
        "USDCARD_EURCARD_out": "1.1270"
      }
    ]
    """;

    private static readonly Dictionary<string, int> Scales = new() { ["RUB"] = 100 };

    [Fact]
    public void Parse_ExtractsDirectSellPairs_AgainstPivot()
    {
        var quotes = BelarusbankRateSource.Parse(
            SampleJson, ["USD", "EUR"], "BYN", Scales, new DateOnly(2000, 1, 1));

        var usd = Assert.Single(quotes, x => x.Base == "USD");
        Assert.Equal("BYN", usd.Quote);
        Assert.Equal(2.95m, usd.Rate); // the SELL (_out) side
        Assert.Equal(FxSource.Belarusbank, usd.Source);

        var eur = Assert.Single(quotes, x => x.Base == "EUR");
        Assert.Equal(3.34m, eur.Rate);
    }

    [Fact]
    public void Parse_ReadsDateFromPayload_NotFallback()
    {
        var quotes = BelarusbankRateSource.Parse(
            SampleJson, ["USD"], "BYN", Scales, new DateOnly(2000, 1, 1));

        Assert.Equal(new DateOnly(2026, 7, 1), Assert.Single(quotes).Date);
    }

    [Fact]
    public void Parse_AppliesPerUnitScale()
    {
        var quotes = BelarusbankRateSource.Parse(
            SampleJson, ["RUB"], "BYN", Scales, new DateOnly(2000, 1, 1));

        // 3.58 quoted per 100 RUB ⇒ 0.0358 BYN per 1 RUB.
        Assert.Equal(0.0358m, Assert.Single(quotes).Rate);
    }

    [Fact]
    public void Parse_IgnoresCrossPairs()
    {
        var quotes = BelarusbankRateSource.Parse(
            SampleJson, ["USD", "EUR"], "BYN", Scales, new DateOnly(2000, 1, 1));

        // USDCARD_EURCARD_out must never surface as a "USD" or "EUR" quote value.
        Assert.DoesNotContain(quotes, x => x.Rate == 1.1270m);
    }

    [Fact]
    public void Parse_ExcludesPivotAndUnwantedCurrencies()
    {
        var quotes = BelarusbankRateSource.Parse(
            SampleJson, ["USD", "BYN"], "BYN", Scales, new DateOnly(2000, 1, 1));

        Assert.DoesNotContain(quotes, x => x.Base == "BYN"); // pivot excluded
        Assert.DoesNotContain(quotes, x => x.Base == "EUR"); // not requested
        Assert.Single(quotes);
    }

    [Fact]
    public void Parse_ReturnsEmpty_OnMalformedJson()
    {
        var quotes = BelarusbankRateSource.Parse(
            "not json", ["USD"], "BYN", Scales, new DateOnly(2000, 1, 1));

        Assert.Empty(quotes);
    }
}

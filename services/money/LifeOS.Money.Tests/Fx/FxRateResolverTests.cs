using LifeOS.Money.Api.Domain.Fx;
using LifeOS.Money.Api.Fx;
using Xunit;

namespace LifeOS.Money.Tests.Fx;

public class FxRateResolverTests
{
    private static readonly string[] Priority = ["belarusbank", "frankfurter"];

    private static FxRate Row(string source, DateOnly date, decimal rate) => new()
    {
        Id = FxRate.MakeId("USD", "BYN", date, source),
        Base = "USD",
        Quote = "BYN",
        Date = date,
        Rate = rate,
        Source = source,
    };

    [Fact]
    public void Resolve_ReturnsNull_WhenNoCandidates()
    {
        Assert.Null(FxRateResolver.Resolve([], new DateOnly(2026, 7, 1), Priority));
    }

    [Fact]
    public void Resolve_PrefersHigherPrioritySource_PerPair()
    {
        // Same date, both sources present — Belarusbank wins per ADR-0015.
        var rows = new[]
        {
            Row(FxSource.Frankfurter, new DateOnly(2026, 7, 1), 3.10m),
            Row(FxSource.Belarusbank, new DateOnly(2026, 7, 1), 2.95m),
        };

        var resolved = FxRateResolver.Resolve(rows, new DateOnly(2026, 7, 1), Priority);

        Assert.Equal(FxSource.Belarusbank, resolved!.Source);
        Assert.Equal(2.95m, resolved.Rate);
    }

    [Fact]
    public void Resolve_PreferredSourceWins_EvenWhenFallbackIsFresher()
    {
        // ADR-0015 fallback is per-pair existence, not per-date freshness: if the
        // preferred source covers the pair at all, use its freshest row.
        var rows = new[]
        {
            Row(FxSource.Belarusbank, new DateOnly(2026, 6, 28), 2.90m),
            Row(FxSource.Frankfurter, new DateOnly(2026, 7, 1), 3.10m),
        };

        var resolved = FxRateResolver.Resolve(rows, new DateOnly(2026, 7, 1), Priority);

        Assert.Equal(FxSource.Belarusbank, resolved!.Source);
        Assert.Equal(2.90m, resolved.Rate);
    }

    [Fact]
    public void Resolve_ForwardFills_MostRecentOnOrBeforeAsOf()
    {
        var rows = new[]
        {
            Row(FxSource.Belarusbank, new DateOnly(2026, 6, 26), 2.80m),
            Row(FxSource.Belarusbank, new DateOnly(2026, 6, 28), 2.90m),
        };

        // Asked for Jun 30 (a gap) — should forward-fill Jun 28, not Jun 26.
        var resolved = FxRateResolver.Resolve(rows, new DateOnly(2026, 6, 30), Priority);

        Assert.Equal(new DateOnly(2026, 6, 28), resolved!.Date);
        Assert.Equal(2.90m, resolved.Rate);
    }

    [Fact]
    public void Resolve_IgnoresRowsAfterAsOf()
    {
        var rows = new[]
        {
            Row(FxSource.Belarusbank, new DateOnly(2026, 6, 28), 2.90m),
            Row(FxSource.Belarusbank, new DateOnly(2026, 7, 5), 3.00m),
        };

        var resolved = FxRateResolver.Resolve(rows, new DateOnly(2026, 7, 1), Priority);

        Assert.Equal(new DateOnly(2026, 6, 28), resolved!.Date);
    }

    [Fact]
    public void Resolve_ExcludesDisabledSource_NotInPriorityList()
    {
        // Only frankfurter enabled: a belarusbank row must be ignored entirely.
        var rows = new[]
        {
            Row(FxSource.Belarusbank, new DateOnly(2026, 7, 1), 2.95m),
            Row(FxSource.Frankfurter, new DateOnly(2026, 7, 1), 3.10m),
        };

        var resolved = FxRateResolver.Resolve(rows, new DateOnly(2026, 7, 1), ["frankfurter"]);

        Assert.Equal(FxSource.Frankfurter, resolved!.Source);
    }
}

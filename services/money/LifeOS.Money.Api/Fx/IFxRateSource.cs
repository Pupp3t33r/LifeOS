namespace LifeOS.Money.Api.Fx;

/// A provider of FX rates (ADR-0015). Implementations fetch from one external
/// source and translate its shape into <see cref="FxQuote"/>s. A source that is
/// down or returns garbage must return an empty list rather than throw — the fetch
/// service tolerates a failed source and relies on the other (precedence), per the
/// ADR's "tolerate its outages and fall back gracefully."
public interface IFxRateSource
{
    /// The <see cref="Domain.Fx.FxSource"/> constant this source writes.
    string Source { get; }

    /// Fetch current rates covering <paramref name="currencies"/> (ISO 4217). The
    /// source decides which of those pairs it can serve; uncovered pairs are simply
    /// omitted. Never throws for an external failure — returns an empty list.
    Task<IReadOnlyList<FxQuote>> FetchAsync(
        IReadOnlyCollection<string> currencies,
        CancellationToken cancellationToken);
}

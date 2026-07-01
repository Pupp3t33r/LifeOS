namespace LifeOS.Money.Api.Domain.Fx;

/// The provider a stored <see cref="FxRate"/> came from (ADR-0015). Persisted as a
/// string on the document so the value is stable and human-readable in the DB, and
/// so precedence (Belarusbank preferred, Frankfurter fallback) reads plainly.
public static class FxSource
{
    /// Belarusbank card SELL rate — the honest cost of a foreign-currency card
    /// transaction for the primary (Belarus) user. Preferred where published.
    public const string Belarusbank = "belarusbank";

    /// Frankfurter (ECB mid-market) — the international fallback for pairs
    /// Belarusbank does not cover.
    public const string Frankfurter = "frankfurter";
}

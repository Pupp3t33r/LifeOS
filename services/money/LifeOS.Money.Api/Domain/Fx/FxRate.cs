namespace LifeOS.Money.Api.Domain.Fx;

/// A single observed FX rate (ADR-0008 / ADR-0015). Stored as a Marten
/// <b>document</b>, not an event: FX rates are external observed data, not
/// user-authored domain state, so they belong in a query-optimized table the
/// fetch service upserts (ADR-0008 "Alternatives Considered" §4).
///
/// One document per <c>(Base, Quote, Date, Source)</c> — the deterministic
/// <see cref="Id"/> makes re-fetching the same day idempotent (an upsert, never a
/// duplicate). Both sources may publish the same pair/date; precedence at read time
/// prefers <see cref="FxSource.Belarusbank"/> over <see cref="FxSource.Frankfurter"/>.
///
/// <see cref="Rate"/> is the amount of <see cref="Quote"/> per 1 unit of
/// <see cref="Base"/> (e.g. Base=USD, Quote=BYN, Rate=2.95 ⇒ 1 USD = 2.95 BYN).
public sealed class FxRate
{
    /// Deterministic document id: <c>"{Base}:{Quote}:{Date:yyyy-MM-dd}:{Source}"</c>.
    /// Composed by <see cref="MakeId"/> so a re-fetch upserts the same row.
    public string Id { get; set; } = string.Empty;

    /// ISO 4217 base currency (the "1 unit of" side).
    public string Base { get; set; } = string.Empty;

    /// ISO 4217 quote currency (the "per unit" side).
    public string Quote { get; set; } = string.Empty;

    /// The date the rate applies to.
    public DateOnly Date { get; set; }

    /// Amount of <see cref="Quote"/> per 1 unit of <see cref="Base"/>.
    public decimal Rate { get; set; }

    /// Which provider produced this row — one of the <see cref="FxSource"/> constants.
    public string Source { get; set; } = string.Empty;

    /// When the fetch service last wrote this row (for observability / staleness).
    public DateTimeOffset RetrievedAt { get; set; }

    public static string MakeId(string @base, string quote, DateOnly date, string source) =>
        $"{@base}:{quote}:{date:yyyy-MM-dd}:{source}";
}

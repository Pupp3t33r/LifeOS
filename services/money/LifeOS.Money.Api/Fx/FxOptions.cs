namespace LifeOS.Money.Api.Fx;

/// Configuration for the FX rate service (ADR-0015), bound from the <c>Fx</c>
/// configuration section. Sensible defaults let the service run with no config;
/// the external URLs are keyless public APIs, so nothing here is a secret.
public sealed class FxOptions
{
    public const string SectionName = "Fx";

    /// Master switch. Off in integration tests so the hosted fetch loop does not
    /// reach out to real external APIs during a test run.
    public bool Enabled { get; set; } = true;

    /// How often the background service fetches (ADR-0015: hourly).
    public TimeSpan FetchInterval { get; set; } = TimeSpan.FromHours(1);

    /// The always-fetch currency set. The fetch service unions this with the
    /// owner's display currency and any account currencies found in the DB.
    public string[] Currencies { get; set; } = ["BYN", "USD", "EUR", "RUB", "CNY", "PLN"];

    /// The pivot currency for Belarusbank direct pairs — every Belarusbank card
    /// rate is quoted against this (BYN). Foreign→pivot SELL rates are stored.
    public string PivotCurrency { get; set; } = "BYN";

    /// Read-side source precedence, most-preferred first. When several sources have a
    /// rate for the same pair/date, the first source listed here wins. All sources are
    /// still stored independently (one row per source) — this only decides which one a
    /// conversion query returns. A future per-user Settings feature (choose priority /
    /// toggle sources on-off) replaces this static list with a per-user ordered list;
    /// a disabled source is simply one omitted from the list. Sources not listed here
    /// are considered lowest priority.
    public string[] SourcePriority { get; set; } = ["belarusbank", "frankfurter"];

    /// Belarusbank card-rates endpoint (returns SELL/BUY per pair).
    public string BelarusbankUrl { get; set; } = "https://belarusbank.by/api/kurs_cards";

    /// Frankfurter base URL (ECB mid-market, keyless).
    public string FrankfurterBaseUrl { get; set; } = "https://api.frankfurter.dev/v1";

    /// A stale-rate warning fires when no stored rate is newer than this many days.
    public int StaleAfterDays { get; set; } = 3;

    /// Per-unit scale for Belarusbank card rates, keyed by ISO code. Belarusbank
    /// quotes some currencies per 100 units (RUB is quoted per 100 — an observed
    /// SELL value near 3.6 BYN is 100 RUB, not 1), so the raw rate is divided by
    /// the scale to normalize to "BYN per 1 unit." Absent ⇒ scale 1. Confirm
    /// against live payloads and adjust here — no code change needed.
    public Dictionary<string, int> BelarusbankUnitScale { get; set; } = new()
    {
        ["RUB"] = 100,
    };
}

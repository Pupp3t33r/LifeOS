using System.Globalization;
using System.Text.Json;
using System.Text.RegularExpressions;
using LifeOS.Money.Api.Domain.Fx;
using Microsoft.Extensions.Options;

namespace LifeOS.Money.Api.Fx;

/// Belarusbank card-rate source (ADR-0015) — the preferred source for the pairs it
/// covers. <c>kurs_cards</c> returns an array of objects whose keys embed the
/// currency and side, e.g. <c>USDCARD_out</c> (SELL) / <c>USDCARD_in</c> (BUY), plus
/// cross-pairs like <c>USDCARD_EURCARD_out</c> and a <c>kurs_date_time</c>. v1 keeps
/// only the direct SELL pairs against the pivot (BYN): the bank <i>sells</i> the user
/// foreign currency when they spend on card, so the sell rate is the honest cost.
///
/// The API is undocumented and informal, so parsing is deliberately defensive: it
/// regex-matches single-currency <c>_out</c> keys (tolerating the optional <c>CARD</c>
/// infix), ignores everything else (cross-pairs, BUY side), and never throws on a
/// malformed payload — a bad response yields an empty list and the fetch falls back
/// to Frankfurter.
public sealed partial class BelarusbankRateSource : IFxRateSource
{
    private readonly HttpClient _http;
    private readonly FxOptions _options;
    private readonly ILogger<BelarusbankRateSource> _logger;

    public BelarusbankRateSource(
        HttpClient http,
        IOptions<FxOptions> options,
        ILogger<BelarusbankRateSource> logger)
    {
        _http = http;
        _options = options.Value;
        _logger = logger;
    }

    public string Source => FxSource.Belarusbank;

    public async Task<IReadOnlyList<FxQuote>> FetchAsync(
        IReadOnlyCollection<string> currencies,
        CancellationToken cancellationToken)
    {
        string json;
        try
        {
            json = await _http.GetStringAsync(_options.BelarusbankUrl, cancellationToken);
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException)
        {
            _logger.LogWarning(ex, "Belarusbank fetch failed; falling back to other sources.");
            return [];
        }

        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        return Parse(json, currencies, _options.PivotCurrency, _options.BelarusbankUnitScale, today, _logger);
    }

    /// Parse a <c>kurs_cards</c> payload into direct foreign→pivot SELL quotes.
    /// Pure and side-effect free so it is unit-testable without HTTP.
    internal static IReadOnlyList<FxQuote> Parse(
        string json,
        IReadOnlyCollection<string> currencies,
        string pivot,
        IReadOnlyDictionary<string, int> scales,
        DateOnly fallbackDate,
        ILogger? logger = null)
    {
        var wanted = currencies
            .Select(x => x.ToUpperInvariant())
            .Where(x => x != pivot.ToUpperInvariant())
            .ToHashSet();

        JsonDocument doc;
        try
        {
            doc = JsonDocument.Parse(json);
        }
        catch (JsonException ex)
        {
            logger?.LogWarning(ex, "Belarusbank payload was not valid JSON.");
            return [];
        }

        using (doc)
        {
            // The endpoint returns an array; be lenient and also accept a bare object.
            var elements = doc.RootElement.ValueKind == JsonValueKind.Array
                ? doc.RootElement.EnumerateArray().ToArray()
                : [doc.RootElement];

            // De-dupe on currency (an array may repeat the same rate per branch);
            // first-seen wins.
            var seen = new HashSet<string>();
            var quotes = new List<FxQuote>();

            foreach (var element in elements)
            {
                if (element.ValueKind != JsonValueKind.Object)
                {
                    continue;
                }

                var date = ReadDate(element, fallbackDate);

                foreach (var property in element.EnumerateObject())
                {
                    var match = SellKeyRegex().Match(property.Name);
                    if (!match.Success)
                    {
                        continue;
                    }

                    var currency = match.Groups[1].Value.ToUpperInvariant();
                    if (!wanted.Contains(currency) || !seen.Add(currency))
                    {
                        continue;
                    }

                    if (!TryReadDecimal(property.Value, out var raw))
                    {
                        continue;
                    }

                    var scale = scales.TryGetValue(currency, out var s) && s > 0 ? s : 1;
                    quotes.Add(new FxQuote(currency, pivot.ToUpperInvariant(), date, raw / scale, FxSource.Belarusbank));
                }
            }

            return quotes;
        }
    }

    private static DateOnly ReadDate(JsonElement element, DateOnly fallback)
    {
        if (element.TryGetProperty("kurs_date_time", out var dt)
            && dt.ValueKind == JsonValueKind.String
            && DateTime.TryParse(
                dt.GetString(), CultureInfo.InvariantCulture, DateTimeStyles.None, out var parsed))
        {
            return DateOnly.FromDateTime(parsed);
        }

        return fallback;
    }

    private static bool TryReadDecimal(JsonElement value, out decimal result)
    {
        if (value.ValueKind == JsonValueKind.Number && value.TryGetDecimal(out result))
        {
            return true;
        }

        if (value.ValueKind == JsonValueKind.String
            && decimal.TryParse(
                value.GetString(), NumberStyles.Number, CultureInfo.InvariantCulture, out result))
        {
            return true;
        }

        result = 0;
        return false;
    }

    // Single-currency SELL key: three-letter code, optional "CARD" infix, "_out".
    // Cross-pairs (USDCARD_EURCARD_out) do not match — the anchored "_out$" fails.
    [GeneratedRegex("^([A-Z]{3})(?:CARD)?_out$", RegexOptions.IgnoreCase)]
    private static partial Regex SellKeyRegex();
}

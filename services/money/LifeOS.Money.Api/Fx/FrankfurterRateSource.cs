using System.Text.Json;
using System.Text.Json.Serialization;
using LifeOS.Money.Api.Domain.Fx;

namespace LifeOS.Money.Api.Fx;

/// Frankfurter (ECB mid-market) rate source — the international fallback (ADR-0015)
/// for pairs Belarusbank does not cover. One request per base currency:
/// <c>GET {base}/latest?base=USD&amp;symbols=EUR,GBP</c> ⇒ <c>{ base, date, rates }</c>.
/// ECB does not publish BYN or RUB, so those bases simply come back empty and are
/// skipped — Belarusbank supplies the pivot side for them.
public sealed class FrankfurterRateSource : IFxRateSource
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    private readonly HttpClient _http;
    private readonly ILogger<FrankfurterRateSource> _logger;

    public FrankfurterRateSource(HttpClient http, ILogger<FrankfurterRateSource> logger)
    {
        _http = http;
        _logger = logger;
    }

    public string Source => FxSource.Frankfurter;

    public async Task<IReadOnlyList<FxQuote>> FetchAsync(
        IReadOnlyCollection<string> currencies,
        CancellationToken cancellationToken)
    {
        var set = currencies.Select(x => x.ToUpperInvariant()).Distinct().ToArray();
        var quotes = new List<FxQuote>();

        foreach (var @base in set)
        {
            var symbols = set.Where(x => x != @base).ToArray();
            if (symbols.Length == 0)
            {
                continue;
            }

            var response = await FetchBaseAsync(@base, symbols, cancellationToken);
            if (response is null)
            {
                continue;
            }

            foreach (var (quote, rate) in response.Rates)
            {
                quotes.Add(new FxQuote(@base, quote.ToUpperInvariant(), response.Date, rate, Source));
            }
        }

        return quotes;
    }

    private async Task<FrankfurterResponse?> FetchBaseAsync(
        string @base,
        string[] symbols,
        CancellationToken cancellationToken)
    {
        var url = $"latest?base={@base}&symbols={string.Join(',', symbols)}";
        try
        {
            using var response = await _http.GetAsync(url, cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                // ECB has no rate for this base (e.g. BYN/RUB) — expected, not an error.
                _logger.LogDebug(
                    "Frankfurter returned {Status} for base {Base}; skipping.",
                    (int)response.StatusCode, @base);
                return null;
            }

            var payload = await response.Content.ReadFromJsonAsync<FrankfurterResponse>(
                JsonOptions, cancellationToken);
            if (payload is null || payload.Rates.Count == 0)
            {
                return null;
            }

            return payload;
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or JsonException)
        {
            _logger.LogWarning(ex, "Frankfurter fetch failed for base {Base}.", @base);
            return null;
        }
    }

    private sealed record FrankfurterResponse(
        [property: JsonPropertyName("base")] string Base,
        [property: JsonPropertyName("date")] DateOnly Date,
        [property: JsonPropertyName("rates")] IReadOnlyDictionary<string, decimal> Rates);
}

using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Domain.Fx;
using Marten;
using Microsoft.Extensions.Options;

namespace LifeOS.Money.Api.Fx;

/// Hourly FX fetch loop (ADR-0015). A plain <see cref="BackgroundService"/> driven by
/// a <see cref="PeriodicTimer"/> — no Quartz; a single hourly job does not justify a
/// scheduling library (the project's minimalist stance). Each tick fetches every
/// registered <see cref="IFxRateSource"/> for the active currency set and upserts the
/// results as <see cref="FxRate"/> documents. Sources that fail return empty and are
/// simply skipped; one bad tick never stops the loop.
public sealed class FxRateFetchService : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly FxOptions _options;
    private readonly ILogger<FxRateFetchService> _logger;

    public FxRateFetchService(
        IServiceScopeFactory scopeFactory,
        IOptions<FxOptions> options,
        ILogger<FxRateFetchService> logger)
    {
        _scopeFactory = scopeFactory;
        _options = options.Value;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!_options.Enabled)
        {
            _logger.LogInformation("FX rate fetch is disabled (Fx:Enabled = false); not scheduling.");
            return;
        }

        // Fetch once at startup so a fresh environment has rates without waiting an
        // hour, then on the periodic cadence.
        await RunOnceAsync(stoppingToken);

        using var timer = new PeriodicTimer(_options.FetchInterval);
        while (await timer.WaitForNextTickAsync(stoppingToken))
        {
            await RunOnceAsync(stoppingToken);
        }
    }

    private async Task RunOnceAsync(CancellationToken cancellationToken)
    {
        try
        {
            await using var scope = _scopeFactory.CreateAsyncScope();
            var session = scope.ServiceProvider.GetRequiredService<IDocumentSession>();
            // Resolved per tick (not captured in the ctor) so each source's typed
            // HttpClient stays managed by IHttpClientFactory (handler rotation).
            var sources = scope.ServiceProvider.GetServices<IFxRateSource>();

            var currencies = await ResolveCurrencySetAsync(session, cancellationToken);

            var quotes = new List<FxQuote>();
            foreach (var source in sources)
            {
                var fetched = await source.FetchAsync(currencies, cancellationToken);
                _logger.LogInformation(
                    "FX source {Source} returned {Count} quotes for {CurrencyCount} currencies.",
                    source.Source, fetched.Count, currencies.Count);
                quotes.AddRange(fetched);
            }

            if (quotes.Count == 0)
            {
                _logger.LogWarning("FX fetch produced no quotes this tick; all sources empty.");
                return;
            }

            var now = DateTimeOffset.UtcNow;
            foreach (var quote in quotes)
            {
                session.Store(new FxRate
                {
                    Id = FxRate.MakeId(quote.Base, quote.Quote, quote.Date, quote.Source),
                    Base = quote.Base,
                    Quote = quote.Quote,
                    Date = quote.Date,
                    Rate = quote.Rate,
                    Source = quote.Source,
                    RetrievedAt = now,
                });
            }

            await session.SaveChangesAsync(cancellationToken);
            _logger.LogInformation("FX fetch upserted {Count} rate rows.", quotes.Count);

            await WarnIfStaleAsync(session, cancellationToken);
        }
        catch (OperationCanceledException)
        {
            // Shutting down — expected.
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "FX fetch tick failed; will retry on the next interval.");
        }
    }

    /// The always-fetch config set, unioned with every display currency chosen by a
    /// user and every account currency in the store, plus the pivot — so the service
    /// keeps rates fresh for whatever the app actually holds.
    private async Task<IReadOnlyCollection<string>> ResolveCurrencySetAsync(
        IQuerySession session,
        CancellationToken cancellationToken)
    {
        var set = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            _options.PivotCurrency,
        };

        foreach (var currency in _options.Currencies)
        {
            set.Add(currency);
        }

        var displayCurrencies = await session.Query<UserPreferences>()
            .Where(x => x.DisplayCurrency != null)
            .Select(x => x.DisplayCurrency!)
            .ToListAsync(cancellationToken);
        foreach (var currency in displayCurrencies)
        {
            set.Add(currency);
        }

        var accountCurrencies = await session.Query<Account>()
            .Select(x => x.Currency)
            .ToListAsync(cancellationToken);
        foreach (var currency in accountCurrencies)
        {
            if (!string.IsNullOrWhiteSpace(currency))
            {
                set.Add(currency);
            }
        }

        return set.Select(x => x.ToUpperInvariant()).ToArray();
    }

    private async Task WarnIfStaleAsync(IQuerySession session, CancellationToken cancellationToken)
    {
        var newest = await session.Query<FxRate>()
            .OrderByDescending(x => x.Date)
            .Select(x => x.Date)
            .FirstOrDefaultAsync(cancellationToken);

        // default(DateOnly) (0001-01-01) means no rows — nothing to warn about.
        if (newest == default)
        {
            return;
        }

        var ageDays = DateOnly.FromDateTime(DateTime.UtcNow).DayNumber - newest.DayNumber;
        if (ageDays > _options.StaleAfterDays)
        {
            _logger.LogWarning(
                "Newest FX rate is {AgeDays} days old (threshold {Threshold}); rates may be stale.",
                ageDays, _options.StaleAfterDays);
        }
    }
}

/// The source that published an [FxRate], mirroring the Money service's
/// `FxSource` (ADR-0015). Named so every conversion in the app stays traceable
/// back to a provider (no false precision).
enum FxRateSource {
  belarusbank,
  frankfurter,
  identity,
  unknown;

  static FxRateSource fromWire(String wire) => switch (wire) {
        'belarusbank' => belarusbank,
        'frankfurter' => frankfurter,
        'identity' => identity,
        _ => unknown,
      };

  /// Lower wins when the same pair is published by more than one source
  /// (ADR-0015 precedence: prefer Belarusbank, fall back to Frankfurter).
  int get precedence => switch (this) {
        belarusbank => 0,
        frankfurter => 1,
        identity => 2,
        unknown => 3,
      };
}

/// A currency-conversion rate as published by one source — the Dart mirror of the
/// Money service's `FxRateResponse` (ADR-0015). [rate] is the amount of [quote]
/// per one unit of [base]; [asOf] is the date the rate actually applies to (it may
/// lag today under forward-fill); [source] names the provider.
class FxRate {
  const FxRate({
    required this.base,
    required this.quote,
    required this.rate,
    required this.asOf,
    required this.source,
  });

  final String base;
  final String quote;
  final double rate;
  final DateTime asOf;
  final FxRateSource source;

  /// A rate counts as stale once its as-of date is older than this. Rates refresh
  /// hourly server-side (ADR-0015); a gap beyond two days signals the fetch is
  /// failing or the source dropped the pair, and the user should distrust it.
  static const Duration stalenessThreshold = Duration(days: 2);

  bool isStaleAsOf(DateTime now) => now.difference(asOf) > stalenessThreshold;

  factory FxRate.fromJson(Map<String, dynamic> json) => FxRate(
        base: json['base'] as String,
        quote: json['quote'] as String,
        rate: (json['rate'] as num).toDouble(),
        asOf: DateTime.parse(json['date'] as String),
        source: FxRateSource.fromWire(json['source'] as String),
      );
}

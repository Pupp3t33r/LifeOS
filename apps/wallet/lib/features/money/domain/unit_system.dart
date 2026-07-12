/// A cosmetic metric/imperial display preference (Money ADR-0036). It maps a
/// [UnitDimension] to its symbol at render time only — **no conversions ever**
/// (a 2 stays a 2 across a kg↔lb relabel). Defaults to metric.
///
/// Rides the wire as an int (STJ default), matching the Money service.
enum UnitSystem {
  metric,
  imperial;

  /// Parses the wire int, defaulting to metric for a missing/null value.
  static UnitSystem fromWire(Object? value) =>
      value == 1 ? UnitSystem.imperial : UnitSystem.metric;

  /// The wire int the backend stores.
  int get wire => index;
}

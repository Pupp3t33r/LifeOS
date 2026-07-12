import 'unit_system.dart';

/// A generic quantity dimension on a line or want (Money ADR-0036). The backend
/// stores only the dimension — **never** a concrete unit (kg, lb, …). The symbol
/// is a UI-only cosmetic rendered from the dimension × the user's [UnitSystem]
/// preference (see [symbol]); **no conversions ever**.
///
/// Rides the wire as an int (STJ default), matching the Money service.
enum UnitDimension {
  pieces,
  mass,
  volume,
  length;

  /// Parses the wire int. Returns `null` for a missing/null value.
  static UnitDimension? fromWire(Object? value) {
    if (value is int) {
      return switch (value) {
        0 => UnitDimension.pieces,
        1 => UnitDimension.mass,
        2 => UnitDimension.volume,
        3 => UnitDimension.length,
        _ => null,
      };
    }
    return null;
  }

  /// The wire int the backend stores.
  int get wire => index;

  /// The cosmetic symbol for this dimension under [system], or `null` when the
  /// dimension has no symbol (Pieces is a bare count — `×2`, never `×2 pcs`).
  /// A finance annotation, not a measurement: switching [UnitSystem] relabels
  /// every quantity without touching its number.
  String? symbol(UnitSystem system) => switch (this) {
        UnitDimension.pieces => null,
        UnitDimension.mass => system == UnitSystem.metric ? 'kg' : 'lb',
        UnitDimension.volume => system == UnitSystem.metric ? 'L' : 'gal',
        UnitDimension.length => system == UnitSystem.metric ? 'm' : 'ft',
      };
}

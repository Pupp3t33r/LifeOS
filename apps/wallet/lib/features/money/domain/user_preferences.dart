import 'unit_system.dart';

/// Dart mirror of the Money service's `PreferencesResponse` (ADR-0013/0036). Holds the
/// per-user config the Wallet needs before the savings canvas can render: the
/// configurable month start day, the display currency the canvas aggregates into, and
/// the cosmetic metric/imperial [unitSystem] that relabels quantity symbols at render
/// time (no conversions).
///
/// A null [displayCurrency] is the canonical "onboarding not yet complete"
/// signal — the router uses [onboardingComplete] to decide whether to show the
/// onboarding flow.
class UserPreferences {
  const UserPreferences({
    required this.monthStartDay,
    required this.displayCurrency,
    this.unitSystem = UnitSystem.metric,
  });

  /// Day of month a period begins (1–31, clamped to the month's last day where
  /// shorter). 1 ⇒ periods are exactly calendar months.
  final int monthStartDay;

  /// ISO 4217 code the canvas/budgets aggregate into. Null until onboarding sets
  /// it (defaulted from the first savings account's currency).
  final String? displayCurrency;

  /// Cosmetic metric/imperial display preference (ADR-0036). Defaults to metric.
  final UnitSystem unitSystem;

  /// True once the user has a display currency — i.e. onboarding is done.
  bool get onboardingComplete => displayCurrency != null;

  /// The implied preferences for a user the server has no document for yet.
  static const UserPreferences defaults =
      UserPreferences(monthStartDay: 1, displayCurrency: null);

  factory UserPreferences.fromJson(Map<String, dynamic> json) => UserPreferences(
        monthStartDay: json['monthStartDay'] as int,
        displayCurrency: json['displayCurrency'] as String?,
        unitSystem: UnitSystem.fromWire(json['unitSystem']),
      );
}

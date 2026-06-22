import 'dart:ui';

/// LifeOS — "Calm" theme · FLUTTER / Dart binding.
///
/// DERIVED FROM `design/themes/calm/tokens.json` (this theme's source of truth).
/// If you change a value here, change `tokens.json` too — see design/README.md.
/// Mirrors `design/themes/calm/bindings/tokens.css`: the Keycloak login wears the
/// CSS binding, the Wallet app wears this one, so login and app stay visually
/// consistent (see apps/wallet/AGENTS.md).
///
/// Vendored into `lib/` because a Flutter package cannot import files outside its
/// own `lib/` tree (unlike the CSS binding, which Keycloak bind-mounts). When
/// Style Dictionary lands it will generate this file from `tokens.json`.
///
/// Token names are this theme's own vocabulary (sage/clay/bone…). Mode-aware
/// values differ between [light] and [dark]; mode-independent values (type,
/// radius) are top-level statics.
class CalmTokens {
  const CalmTokens({
    required this.bone,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.line,
    required this.sage,
    required this.sageDeep,
    required this.clay,
    required this.focusRing,
    required this.shadowCard,
  });

  /// Page background.
  final Color bone;

  /// Card / raised surface.
  final Color surface;

  /// Primary text.
  final Color ink;

  /// Secondary / muted text.
  final Color muted;

  /// Hairline borders and dividers.
  final Color line;

  /// Brand primary.
  final Color sage;

  /// Brand primary, deeper (gradients, pressed states).
  final Color sageDeep;

  /// Accent.
  final Color clay;

  /// Focus ring.
  final Color focusRing;

  /// Card drop shadow.
  final Color shadowCard;

  /// Mode-independent — white stays white in both modes.
  static const Color white = Color(0xFFFFFFFF);

  static const CalmTokens light = CalmTokens(
    bone: Color(0xFFF4F1EA),
    surface: Color(0xFFFBFAF6),
    ink: Color(0xFF2C2A26),
    muted: Color(0xFF7C766B),
    line: Color(0xFFE6E1D6),
    sage: Color(0xFF5E7E6B),
    sageDeep: Color(0xFF4E6B5A),
    clay: Color(0xFFC07A52),
    focusRing: Color(0x385E7E6B),
    shadowCard: Color(0x66201E1A),
  );

  static const CalmTokens dark = CalmTokens(
    bone: Color(0xFF15120E),
    surface: Color(0xFF211C16),
    ink: Color(0xFFEDE7DC),
    muted: Color(0xFF9C9384),
    line: Color(0xFF332D24),
    sage: Color(0xFF8FB39E),
    sageDeep: Color(0xFFA7C6B6),
    clay: Color(0xFFD9966E),
    focusRing: Color(0x528FB39E),
    shadowCard: Color(0x9E000000),
  );

  // ---- type (mode-independent) ----
  // Font assets are not bundled yet (deferred with Style Dictionary); these
  // family names fall back to the platform default until the fonts ship.
  static const String fontDisplay = 'Bricolage Grotesque';
  static const String fontBody = 'Spline Sans';

  // ---- radius (mode-independent) ----
  static const double radiusSm = 14;
  static const double radiusMd = 18;
  static const double radiusLg = 28;
  static const double radiusPill = 999;
}

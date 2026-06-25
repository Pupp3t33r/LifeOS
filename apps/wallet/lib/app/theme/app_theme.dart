import 'package:flutter/material.dart';
import 'calm_tokens.dart';

/// The **Calm** theme, bound from [CalmTokens] (derived from
/// `design/themes/calm/tokens.json`). Wallet wears Calm so the app matches the
/// themed Keycloak sign-in page. Do not hardcode colors in feature code —
/// reference `Theme.of(context)` (or `CalmTokens` for tokens Material doesn't
/// model) instead.
ThemeData _buildTheme(CalmTokens t, Brightness brightness) {
  // Label color for filled brand surfaces (primary/secondary). In light mode the
  // brand colors (sage/clay) are deep enough to carry white text; in dark mode
  // they are light tints, so white fails contrast — use the dark page color (bone)
  // as near-black ink instead.
  final onBrand = brightness == Brightness.dark ? t.bone : CalmTokens.white;

  final scheme = ColorScheme.fromSeed(
    seedColor: t.sage,
    brightness: brightness,
  ).copyWith(
    primary: t.sage,
    onPrimary: onBrand,
    secondary: t.clay,
    onSecondary: onBrand,
    surface: t.surface,
    onSurface: t.ink,
    outline: t.line,
    outlineVariant: t.line,
  );

  final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(CalmTokens.radiusLg),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: t.bone,
    fontFamily: CalmTokens.fontBody,
    appBarTheme: AppBarTheme(
      backgroundColor: t.bone,
      foregroundColor: t.ink,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: t.surface,
      elevation: 0,
      shape: cardShape,
      shadowColor: t.shadowCard,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
        ),
        textStyle: const TextStyle(
          fontFamily: CalmTokens.fontDisplay,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: t.line),
        foregroundColor: t.ink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
        ),
        textStyle: const TextStyle(
          fontFamily: CalmTokens.fontDisplay,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: t.sageDeep),
    ),
    dividerTheme: DividerThemeData(color: t.line, space: 1, thickness: 1),
  );
}

/// Calm — light mode.
final ThemeData walletLightTheme = _buildTheme(CalmTokens.light, Brightness.light);

/// Calm — dark mode.
final ThemeData walletDarkTheme = _buildTheme(CalmTokens.dark, Brightness.dark);

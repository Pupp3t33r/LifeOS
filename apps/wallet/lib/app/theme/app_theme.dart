import 'package:flutter/material.dart';

/// TEMPORARY placeholder theme.
///
/// Phase 5 replaces this with the **Calm** theme bound from
/// `design/themes/calm/bindings/tokens.dart` (see apps/wallet/AGENTS.md line 102).
/// Do not hardcode colors in feature code — reference the theme instead.
/// The seed below is a stand-in sage tone so the shell isn't default purple.
final ThemeData walletTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7C8C7A)),
  useMaterial3: true,
);

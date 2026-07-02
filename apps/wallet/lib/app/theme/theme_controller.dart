import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme_store.dart';

final themeStoreProvider = Provider<ThemeStore>((ref) => ThemeStore());

/// App-wide [ThemeMode], watched by [MaterialApp.router].
///
/// [ThemeMode.system] means "follow the device"; light/dark are explicit user
/// overrides, persisted device-locally via [ThemeStore]. A client-only preference,
/// never a Money `UserPreferences` (ADR-0013).
///
/// The stored choice is restored asynchronously on first build: the first frame
/// follows the system, then snaps to the saved mode once secure storage resolves —
/// the same pattern as [LocaleController].
class ThemeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _restore();
    return ThemeMode.system;
  }

  Future<void> _restore() async {
    state = await ref.read(themeStoreProvider).read();
  }

  /// Switch the theme mode and persist it.
  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await ref.read(themeStoreProvider).write(mode);
  }
}

final themeControllerProvider =
    NotifierProvider<ThemeController, ThemeMode>(ThemeController.new);

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Device-local persistence of the chosen [ThemeMode] — follow system, or force
/// light/dark.
///
/// Like `LocaleStore`/`AppLockStore`, this is a **per-device client preference**
/// (your phone may sit in dark mode while your desktop stays light), so it lives in
/// local secure storage, never in Money's `UserPreferences` (ADR-0013). Theme is
/// purely presentational and changes nothing the server computes.
///
/// Absent value = the user has never chosen → [ThemeMode.system] (follow the OS).
class ThemeStore {
  ThemeStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _key = 'theme_mode';

  /// The stored mode, or [ThemeMode.system] when unset / unrecognised.
  Future<ThemeMode> read() async => switch (await _storage.read(key: _key)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  /// Persist the chosen [mode].
  Future<void> write(ThemeMode mode) => _storage.write(
        key: _key,
        value: switch (mode) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          ThemeMode.system => 'system',
        },
      );
}

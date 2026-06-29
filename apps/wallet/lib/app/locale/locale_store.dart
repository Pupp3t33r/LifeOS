import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Device-local persistence of the chosen UI language code (e.g. `'en'`, `'ru'`).
///
/// Like [AppLockStore], this is a **per-device client preference** — your phone
/// may be in Russian while your desktop is in English — so it lives in local
/// storage, never in Money's `UserPreferences` (ADR-0013). Language is purely
/// presentational and changes nothing the server computes, so the Wallet rule
/// "server-affecting config lives on the server" does not pull it onto Money.
/// See `apps/wallet/docs/adr/0001-app-localization.md`.
///
/// Absent value = the user has never chosen a language → follow the system locale.
class LocaleStore {
  LocaleStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _key = 'ui_locale';

  /// The stored language code, or null when unset (follow the system locale).
  Future<String?> read() => _storage.read(key: _key);

  /// Persist the chosen language [code], or clear it (null) to follow the system.
  Future<void> write(String? code) => code == null
      ? _storage.delete(key: _key)
      : _storage.write(key: _key, value: code);
}

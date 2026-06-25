import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Device-local persistence of the "lock the app with biometrics" preference.
/// Deliberately **not** a Money `UserPreferences` (ADR-0013): this is per-device —
/// you may want the lock on your phone but not your desktop — so it lives in local
/// secure storage, never on the server.
class AppLockStore {
  AppLockStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _key = 'app_lock_enabled';

  /// Defaults to false when unset, so a user who never opted in is never locked
  /// out; onboarding/settings is what turns it on.
  Future<bool> isEnabled() async => (await _storage.read(key: _key)) == 'true';

  Future<void> setEnabled(bool value) =>
      _storage.write(key: _key, value: value ? 'true' : 'false');
}

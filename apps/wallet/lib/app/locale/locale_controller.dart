import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'locale_store.dart';

final localeStoreProvider = Provider<LocaleStore>((ref) => LocaleStore());

/// App-wide UI language, watched by [MaterialApp.router].
///
/// `null` means "follow the device/system locale" (Flutter resolves it against
/// the supported set). A non-null value is the user's explicit choice, persisted
/// device-locally via [LocaleStore]. This is a client-only presentation
/// preference, never a Money `UserPreferences` (ADR-0013) — see
/// `apps/wallet/docs/adr/0001-app-localization.md`.
///
/// The stored choice is restored asynchronously on first build: the first frame
/// renders in the system locale, then snaps to the saved language once secure
/// storage resolves.
class LocaleController extends Notifier<Locale?> {
  @override
  Locale? build() {
    _restore();
    return null;
  }

  Future<void> _restore() async {
    final code = await ref.read(localeStoreProvider).read();
    if (code != null) {
      state = Locale(code);
    }
  }

  /// Switch the UI language. Pass null to fall back to the system locale.
  Future<void> setLocale(Locale? locale) async {
    state = locale;
    await ref.read(localeStoreProvider).write(locale?.languageCode);
  }
}

final localeControllerProvider =
    NotifierProvider<LocaleController, Locale?>(LocaleController.new);

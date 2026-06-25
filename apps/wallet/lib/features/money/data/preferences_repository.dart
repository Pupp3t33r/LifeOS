import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/user_preferences.dart';
import 'money_api.dart';

/// Talks to the Money service for the onboarding/settings surface: reads and
/// writes [UserPreferences] (ADR-0013) and opens the first savings account.
///
/// Hand-rolled over [Dio] for the handful of endpoints onboarding needs; the
/// generated OpenAPI dart-dio client (apps/wallet/AGENTS.md) supersedes this when
/// it lands.
class PreferencesRepository {
  PreferencesRepository(this._dio);

  final Dio _dio;

  Future<UserPreferences> fetch() async {
    final res = await _dio.get<Map<String, dynamic>>('/preferences');
    return UserPreferences.fromJson(res.data!);
  }

  Future<UserPreferences> setDisplayCurrency(String currency) async {
    final res = await _dio.put<Map<String, dynamic>>(
      '/preferences/display-currency',
      data: {'currency': currency},
    );
    return UserPreferences.fromJson(res.data!);
  }

  Future<UserPreferences> setMonthStartDay(int monthStartDay) async {
    final res = await _dio.put<Map<String, dynamic>>(
      '/preferences/month-start-day',
      data: {'monthStartDay': monthStartDay},
    );
    return UserPreferences.fromJson(res.data!);
  }

  /// Opens the first savings account. The id is client-assigned (ADR-0003) so the
  /// call is idempotent on retry.
  Future<void> openAccount({
    required String name,
    required String currency,
    double? openingBalance,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/accounts',
      data: {
        'accountId': _uuidV4(),
        'name': name,
        'currency': currency,
        'openingBalanceAmount': openingBalance,
      },
    );
  }
}

final preferencesRepositoryProvider = Provider<PreferencesRepository>(
  (ref) => PreferencesRepository(ref.watch(moneyApiProvider)),
);

/// A random RFC-4122 v4 UUID. Local because the app pulls in no `uuid` package
/// for a single call site.
String _uuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1
  String hex(int b) => b.toRadixString(16).padLeft(2, '0');
  final h = bytes.map(hex).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}'
      '-${h.substring(16, 20)}-${h.substring(20)}';
}

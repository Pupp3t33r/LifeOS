import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/auth/auth_controller.dart';

/// Base URL for Money calls. Everything goes through the Gateway under
/// `/api/money/*` (same origin on web → no CORS; see apps/wallet/AGENTS.md). The
/// same web build works in dev/staging/prod because it derives the origin at
/// runtime; native/desktop fall back to the local Gateway. Override with
/// `--dart-define=MONEY_API_BASE=https://app.example.com/api/money`.
class MoneyApi {
  MoneyApi._();

  static String get baseUrl {
    const override = String.fromEnvironment('MONEY_API_BASE');
    if (override.isNotEmpty) return override;
    if (kIsWeb) return '${Uri.base.origin}/api/money';
    return 'http://localhost:5022/api/money';
  }
}

/// A [Dio] configured for the Money API: base URL plus a bearer-token
/// interceptor that pulls the current access token from the OIDC manager at
/// request time (so it always sends a freshly-refreshed token, never a captured
/// stale one).
final moneyApiProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(baseUrl: MoneyApi.baseUrl));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = ref.read(authManagerProvider).currentUser?.token.accessToken;
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ),
  );
  return dio;
});

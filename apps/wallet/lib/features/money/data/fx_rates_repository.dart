import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/fx_rate.dart';
import 'money_api.dart';

/// Reads the FX rates the Money service publishes (ADR-0015). Hand-rolled over
/// [Dio] like the other read surfaces; the generated OpenAPI client supersedes
/// this when it lands (apps/wallet/AGENTS.md).
class FxRatesRepository {
  FxRatesRepository(this._dio);

  final Dio _dio;

  /// Every source's newest rate per pair (`GET /fx-rates/latest`) — one row per
  /// (base, quote, source), NOT collapsed by precedence. The caller decides which
  /// to show; the server already limits the stored set to the user's currencies.
  Future<List<FxRate>> fetchLatest() async {
    final res = await _dio.get<List<dynamic>>('/fx-rates/latest');
    return [
      for (final row in res.data ?? const [])
        FxRate.fromJson(row as Map<String, dynamic>),
    ];
  }
}

final fxRatesRepositoryProvider = Provider<FxRatesRepository>(
  (ref) => FxRatesRepository(ref.watch(moneyApiProvider)),
);

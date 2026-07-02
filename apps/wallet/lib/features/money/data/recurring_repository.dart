import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/recurring/date_only.dart';
import '../domain/recurring/occurrence.dart';
import '../domain/recurring/recurring_payment.dart';
import 'money_api.dart';

/// Read access to the Money service's recurring feature (ADR-0017): the caller's
/// recurring definitions and the occurrences each produces in a window. Hand-rolled
/// over [Dio] like the other Money repositories (the generated OpenAPI client
/// supersedes the HTTP half when it lands). No local cache yet — a just-created
/// recurring's occurrences appear once its create op drains (offline occurrence
/// projection is deferred; see `app/sync/README.md`).
class RecurringRepository {
  RecurringRepository(this._dio);

  final Dio _dio;

  /// All of the caller's recurring payments (active and cancelled), by name.
  Future<List<RecurringPayment>> list() async {
    final res = await _dio.get<List<dynamic>>('/recurring');
    return [
      for (final x in res.data ?? const [])
        RecurringPayment.fromJson(x as Map<String, dynamic>),
    ];
  }

  /// Occurrences of one recurring due in `[from, to]`, each with its derived status
  /// (projected / paid / skipped).
  Future<List<Occurrence>> occurrences(
    String id, {
    required DateTime from,
    required DateTime to,
  }) async {
    final res = await _dio.get<List<dynamic>>(
      '/recurring/$id/occurrences',
      queryParameters: {'from': dateOnlyString(from), 'to': dateOnlyString(to)},
    );
    return [
      for (final x in res.data ?? const [])
        Occurrence.fromJson(x as Map<String, dynamic>),
    ];
  }
}

final recurringRepositoryProvider = Provider<RecurringRepository>(
  (ref) => RecurringRepository(ref.watch(moneyApiProvider)),
);

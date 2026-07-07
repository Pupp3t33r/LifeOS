import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/planned_purchase.dart';
import 'money_api.dart';

/// Read access to the Money service's planned purchases (ADR-0018): the caller's
/// planned purchases for one period, each with its derived status (planned / paid).
/// Hand-rolled over [Dio] like the other Money repositories. No local cache yet — a
/// just-added planned purchase appears once its add op drains (offline projection is
/// deferred, mirroring recurring; see `app/sync/README.md`).
class PlannedPurchaseRepository {
  PlannedPurchaseRepository(this._dio);

  final Dio _dio;

  /// The period's planned purchases (cancelled ones are already gone; paid ones carry
  /// their settling actuals).
  Future<List<PlannedPurchase>> list(int year, int month) async {
    final res = await _dio.get<List<dynamic>>('/months/$year/$month/planned-purchases');
    return [
      for (final x in res.data ?? const [])
        PlannedPurchase.fromJson(x as Map<String, dynamic>),
    ];
  }
}

final plannedPurchaseRepositoryProvider = Provider<PlannedPurchaseRepository>(
  (ref) => PlannedPurchaseRepository(ref.watch(moneyApiProvider)),
);

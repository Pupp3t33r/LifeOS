import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/period_budget.dart';
import 'money_api.dart';

/// Read access to the Money service's per-period budget (ADR-0035): the savings target,
/// category limits, and tracked set for one period. Writes go through the outbox.
class BudgetRepository {
  BudgetRepository(this._dio);

  final Dio _dio;

  Future<PeriodBudget> get(int year, int month) async {
    final res = await _dio.get<Map<String, dynamic>>('/budgets', queryParameters: {
      'year': year,
      'month': month,
    });
    return PeriodBudget.fromJson(res.data ?? {'year': year, 'month': month});
  }
}

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => BudgetRepository(ref.watch(moneyApiProvider)),
);

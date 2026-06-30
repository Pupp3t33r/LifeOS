import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/category.dart';
import 'money_api.dart';

/// Reads the managed category overlay (ADR-0024) from the Money service — the
/// system built-ins unioned with the user's own categories.
///
/// Hand-rolled over [Dio] like `PreferencesRepository`; the generated OpenAPI
/// dart-dio client (apps/wallet/AGENTS.md) supersedes this when it lands.
class CategoriesRepository {
  CategoriesRepository(this._dio);

  final Dio _dio;

  Future<List<Category>> fetch() async {
    final res = await _dio.get<List<dynamic>>('/categories');
    return res.data!
        .map((x) => Category.fromJson(x as Map<String, dynamic>))
        .toList();
  }
}

final categoriesRepositoryProvider = Provider<CategoriesRepository>(
  (ref) => CategoriesRepository(ref.watch(moneyApiProvider)),
);

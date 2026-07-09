import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/category.dart';
import 'money_api.dart';
import 'package:dio/dio.dart';

/// Reads the managed category overlay (ADR-0024) from the Money service — the
/// system built-ins unioned with the user's own categories. Writes go through the
/// outbox (`CategoryOutbox`), not here.
///
/// Hand-rolled over [Dio] like `PreferencesRepository`; the generated OpenAPI
/// dart-dio client (apps/wallet/AGENTS.md) supersedes this when it lands.
class CategoriesRepository {
  CategoriesRepository(this._dio);

  final Dio _dio;

  /// The overlay. [includeArchived] = true asks for the owner's archived
  /// categories too (Money ADR-0033) — the management screen (Wallet ADR-0008)
  /// passes it; the picker leaves it false.
  Future<List<Category>> fetch({bool includeArchived = false}) async {
    final res = await _dio.get<List<dynamic>>(
      '/categories',
      queryParameters: {if (includeArchived) 'includeArchived': true},
    );
    return res.data!
        .map((x) => Category.fromJson(x as Map<String, dynamic>))
        .toList();
  }
}

final categoriesRepositoryProvider = Provider<CategoriesRepository>(
  (ref) => CategoriesRepository(ref.watch(moneyApiProvider)),
);

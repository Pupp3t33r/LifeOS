import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/wishlist_item.dart';
import '../domain/wishlist_schedule_chip.dart';
import 'money_api.dart';

/// Read access to the Money service's wishlist (ADR-0022/0034/0036): the caller's wants
/// (each with its derived commitment status) and packages. Hand-rolled over [Dio] like
/// the other Money repositories; writes go through the outbox. The [schedule] read is
/// the chip composition over the planned-purchase store (ADR-0034 §"Board horizon").
class WishlistRepository {
  WishlistRepository(this._dio);

  final Dio _dio;

  Future<Wishlist> get() async {
    final res = await _dio.get<Map<String, dynamic>>('/wishlist');
    return Wishlist.fromJson(res.data ?? const {});
  }

  /// A want's schedule chips — current + future only (ADR-0034 §"Board horizon").
  /// Pass [fromYear]/[fromMonth] to anchor the window at the current month; omit
  /// for the server's default.
  Future<List<WishlistScheduleChip>> schedule(
    String itemId, {
    int? fromYear,
    int? fromMonth,
  }) async {
    final query = <String, dynamic>{};
    if (fromYear != null) query['fromYear'] = fromYear;
    if (fromMonth != null) query['fromMonth'] = fromMonth;
    final res = await _dio.get<List<dynamic>>(
      '/wishlist/items/$itemId/schedule',
      queryParameters: query,
    );
    return [
      for (final x in res.data ?? const [])
        WishlistScheduleChip.fromJson(x as Map<String, dynamic>),
    ];
  }
}

final wishlistRepositoryProvider = Provider<WishlistRepository>(
  (ref) => WishlistRepository(ref.watch(moneyApiProvider)),
);

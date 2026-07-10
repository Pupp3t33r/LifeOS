import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/wishlist_item.dart';
import 'money_api.dart';

/// Read access to the Money service's wishlist (ADR-0022/0034): the caller's wants (each
/// with its derived commitment status) and packages. Hand-rolled over [Dio] like the
/// other Money repositories; writes go through the outbox.
class WishlistRepository {
  WishlistRepository(this._dio);

  final Dio _dio;

  Future<Wishlist> get() async {
    final res = await _dio.get<Map<String, dynamic>>('/wishlist');
    return Wishlist.fromJson(res.data ?? const {});
  }
}

final wishlistRepositoryProvider = Provider<WishlistRepository>(
  (ref) => WishlistRepository(ref.watch(moneyApiProvider)),
);

import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/data/outbox_repository.dart';
import '../../../../app/sync/outbox_drainer.dart';
import '../../domain/unit_dimension.dart';
import '../../domain/wishlist_item.dart';

/// Money-specific bridge onto the generic outbox for the wishlist (ADR-0022/0034). Every
/// mutation — create/edit/delete a want, create/edit/delete a package — is durably
/// queued and replayed by the shared drainer, exactly like the other outbox bridges: the
/// local write is the "saved before the server" guarantee, and each op is idempotent (a
/// duplicate create is a 200 → already applied). Client-assigned ids (ADR-0003).
class WishlistOutbox {
  WishlistOutbox(this._outbox, this._drainer);

  final OutboxRepository _outbox;
  final OutboxDrainer _drainer;

  Future<void> createItem({
    required String id,
    required WishlistRecurrence recurrence,
    String? name,
    String? notes,
    double? estimateAmount,
    String? estimateCurrency,
    String? categoryId,
    UnitDimension? defaultUnitDimension,
    String? packageId,
    DateTime? now,
  }) {
    final payload = jsonEncode({
      'id': id,
      'recurrence': recurrence.wire,
      'name': name,
      'notes': notes,
      'estimate': estimateAmount == null
          ? null
          : {'amount': estimateAmount, 'currency': estimateCurrency},
      'categoryId': categoryId,
      'defaultUnitDimension': defaultUnitDimension?.wire,
      'packageId': packageId,
      'externalRef': null,
    });
    return _enqueue(id, 'create_wishlist_item', 'POST', '/wishlist/items', payload, now);
  }

  /// Deterministic op id so a re-edit while the previous one is pending replaces it
  /// (last-write-wins offline).
  Future<void> editItem({
    required String id,
    required WishlistRecurrence recurrence,
    String? name,
    String? notes,
    double? estimateAmount,
    String? estimateCurrency,
    String? categoryId,
    UnitDimension? defaultUnitDimension,
    String? packageId,
    DateTime? now,
  }) {
    final payload = jsonEncode({
      'recurrence': recurrence.wire,
      'name': name,
      'notes': notes,
      'estimate': estimateAmount == null
          ? null
          : {'amount': estimateAmount, 'currency': estimateCurrency},
      'categoryId': categoryId,
      'defaultUnitDimension': defaultUnitDimension?.wire,
      'packageId': packageId,
      'externalRef': null,
    });
    return _enqueue('edit_wishlist_$id', 'edit_wishlist_item', 'PUT', '/wishlist/items/$id', payload, now);
  }

  Future<void> deleteItem({required String id, DateTime? now}) {
    final payload = jsonEncode({'id': id});
    return _enqueue('delete_wishlist_$id', 'delete_wishlist_item', 'DELETE', '/wishlist/items/$id', payload, now);
  }

  Future<void> createPackage({required String id, required String name, DateTime? now}) {
    final payload = jsonEncode({'id': id, 'name': name});
    return _enqueue(id, 'create_wishlist_package', 'POST', '/wishlist/packages', payload, now);
  }

  Future<void> editPackage({required String id, required String name, DateTime? now}) {
    final payload = jsonEncode({'name': name});
    return _enqueue('edit_package_$id', 'edit_wishlist_package', 'PUT', '/wishlist/packages/$id', payload, now);
  }

  Future<void> deletePackage({required String id, DateTime? now}) {
    final payload = jsonEncode({'id': id});
    return _enqueue('delete_package_$id', 'delete_wishlist_package', 'DELETE', '/wishlist/packages/$id', payload, now);
  }

  Future<void> _enqueue(
    String id, String kind, String method, String path, String payload, DateTime? now,
  ) async {
    await _outbox.enqueue(
      id: id, kind: kind, method: method, path: path, payload: payload,
      now: now ?? DateTime.now(),
    );
    unawaited(_drainer.drain());
  }
}

final wishlistOutboxProvider = Provider<WishlistOutbox>(
  (ref) => WishlistOutbox(
    ref.watch(outboxRepositoryProvider),
    ref.watch(outboxDrainerProvider),
  ),
);

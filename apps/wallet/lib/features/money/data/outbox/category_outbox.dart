import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/data/outbox_repository.dart';
import '../../../../app/sync/outbox_drainer.dart';

/// Money-specific bridge onto the generic outbox for category writes (Money
/// ADR-0033): each mutation is durably queued and a drain is kicked off but not
/// awaited, so the UI never blocks on the network (Wallet ADR-0004).
///
/// The client mints the category id (Money ADR-0003), so **create** uses that id
/// as the outbox row id (a re-enqueue replaces, giving natural idempotency). The
/// lifecycle mutations (rename/archive/unarchive) each get a fresh row id so they
/// queue in order behind the create rather than overwriting it.
class CategoryOutbox {
  CategoryOutbox(this._outbox, this._drainer);

  final OutboxRepository _outbox;
  final OutboxDrainer _drainer;

  Future<void> create({required String id, required String name}) {
    return _enqueue(
      rowId: id,
      kind: 'create_category',
      method: 'POST',
      path: '/categories',
      payload: jsonEncode({'id': id, 'name': name}),
    );
  }

  Future<void> rename({required String id, required String name}) {
    return _enqueue(
      rowId: 'cat-rename:$id:${_uuidV4()}',
      kind: 'rename_category',
      method: 'PATCH',
      path: '/categories/$id',
      payload: jsonEncode({'name': name}),
    );
  }

  Future<void> archive(String id) {
    return _enqueue(
      rowId: 'cat-archive:$id:${_uuidV4()}',
      kind: 'archive_category',
      method: 'POST',
      path: '/categories/$id/archive',
      payload: '{}',
    );
  }

  Future<void> unarchive(String id) {
    return _enqueue(
      rowId: 'cat-unarchive:$id:${_uuidV4()}',
      kind: 'unarchive_category',
      method: 'POST',
      path: '/categories/$id/unarchive',
      payload: '{}',
    );
  }

  Future<void> _enqueue({
    required String rowId,
    required String kind,
    required String method,
    required String path,
    required String payload,
  }) async {
    await _outbox.enqueue(
      id: rowId,
      kind: kind,
      method: method,
      path: path,
      payload: payload,
      now: DateTime.now(),
    );
    unawaited(_drainer.drain());
  }
}

final categoryOutboxProvider = Provider<CategoryOutbox>(
  (ref) => CategoryOutbox(
    ref.watch(outboxRepositoryProvider),
    ref.watch(outboxDrainerProvider),
  ),
);

/// A random RFC-4122 v4 UUID (mirrors `FlowOutbox`; the app pulls in no `uuid`
/// package for a couple of call sites).
String _uuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int b) => b.toRadixString(16).padLeft(2, '0');
  final h = bytes.map(hex).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}'
      '-${h.substring(16, 20)}-${h.substring(20)}';
}

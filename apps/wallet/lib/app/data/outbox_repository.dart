import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_database.dart';
import 'operation_status.dart';

/// Read/write access to the [PendingOperations] outbox.
///
/// The UI calls [enqueue] and returns the moment the local row is committed —
/// that local write *is* the "stored before going to the server" guarantee. The
/// drainer (`app/sync`) consumes the rest of this surface to replay rows and
/// retire them. No HTTP happens here.
class OutboxRepository {
  OutboxRepository(this._db);

  final AppDatabase _db;

  /// Durably queue a server mutation as [OperationStatus.pending].
  ///
  /// Idempotent on [id]: re-enqueuing the same client-assigned id replaces the
  /// existing row instead of duplicating it, so a double-tap or an at-least-once
  /// retry can never create two operations for one logical action.
  Future<void> enqueue({
    required String id,
    required String kind,
    required String method,
    required String path,
    required String payload,
    required DateTime now,
  }) async {
    await _db.into(_db.pendingOperations).insertOnConflictUpdate(
          PendingOperationsCompanion.insert(
            id: id,
            kind: kind,
            method: method,
            path: path,
            payload: payload,
            status: OperationStatus.pending,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  /// Live view of operations not yet retired — [OperationStatus.pending] or
  /// [OperationStatus.syncing] — oldest first, which is also the drain order.
  /// Re-emits on every outbox change.
  Stream<List<PendingOperation>> watchPending() {
    return (_db.select(_db.pendingOperations)
          ..where((x) =>
              x.status.equalsValue(OperationStatus.pending) |
              x.status.equalsValue(OperationStatus.syncing))
          ..orderBy([(x) => OrderingTerm.asc(x.createdAt)]))
        .watch();
  }

  /// One-shot snapshot of the drain queue (pending + syncing), oldest first.
  Future<List<PendingOperation>> pending() {
    return (_db.select(_db.pendingOperations)
          ..where((x) =>
              x.status.equalsValue(OperationStatus.pending) |
              x.status.equalsValue(OperationStatus.syncing))
          ..orderBy([(x) => OrderingTerm.asc(x.createdAt)]))
        .get();
  }

  /// Claim a row for sending: flip it to [OperationStatus.syncing] and bump the
  /// attempt count. Returns false if the row is no longer claimable (already
  /// retired or claimed by another drain pass).
  Future<bool> markSyncing(String id, {required DateTime now}) async {
    final updated = await (_db.update(_db.pendingOperations)
          ..where((x) =>
              x.id.equals(id) &
              x.status.equalsValue(OperationStatus.pending)))
        .write(PendingOperationsCompanion.custom(
      status: Constant(OperationStatus.syncing.name),
      attempts: _db.pendingOperations.attempts + const Constant(1),
      updatedAt: Variable(now),
    ));
    return updated > 0;
  }

  /// Mark a successfully-replayed row as [OperationStatus.synced].
  Future<void> markSynced(String id, {required DateTime now}) async {
    await (_db.update(_db.pendingOperations)..where((x) => x.id.equals(id)))
        .write(PendingOperationsCompanion(
      status: const Value(OperationStatus.synced),
      updatedAt: Value(now),
    ));
  }

  /// Mark a row as non-retryably [OperationStatus.failed] (a 4xx the user must
  /// resolve), recording [error] for display.
  Future<void> markFailed(
    String id, {
    required String error,
    required DateTime now,
  }) async {
    await (_db.update(_db.pendingOperations)..where((x) => x.id.equals(id)))
        .write(PendingOperationsCompanion(
      status: const Value(OperationStatus.failed),
      lastError: Value(error),
      updatedAt: Value(now),
    ));
  }

  /// Return a claimed-but-unsent row to [OperationStatus.pending] for a later
  /// drain — used when a send fails transiently (offline, timeout, 5xx). The
  /// attempt bump from [markSyncing] is kept so backoff can grow.
  Future<void> releasePending(
    String id, {
    String? error,
    required DateTime now,
  }) async {
    await (_db.update(_db.pendingOperations)..where((x) => x.id.equals(id)))
        .write(PendingOperationsCompanion(
      status: const Value(OperationStatus.pending),
      lastError: Value(error),
      updatedAt: Value(now),
    ));
  }
}

/// App-lifetime outbox repository over the local [AppDatabase].
final outboxRepositoryProvider = Provider<OutboxRepository>(
  (ref) => OutboxRepository(ref.watch(appDatabaseProvider)),
);

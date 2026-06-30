import 'package:drift/drift.dart';
import 'operation_status.dart';

/// The durable outbox: one row per queued server mutation, written *before* the
/// network call so the action survives app restarts and offline gaps.
///
/// Deliberately operation-agnostic — a row records *what HTTP call to replay*,
/// not what it means (see apps/wallet/AGENTS.md, "Data and sync — read models +
/// outbox"). Money's client-assigned ids (ADR-0003) live inside [payload], which
/// is what makes blind replay-after-uncertain-failure idempotent: the server
/// dedups on the embedded id.
class PendingOperations extends Table {
  @override
  String get tableName => 'pending_operations';

  /// Client-assigned id of the operation; doubles as the idempotency key. For a
  /// record-transaction op this mirrors the `transactionId` carried in
  /// [payload], so the row and the server resource share one identity.
  TextColumn get id => text()();

  /// Diagnostic/routing label, e.g. `record_transaction`. The drainer does not
  /// interpret it — it replays [method]/[path]/[payload] verbatim.
  TextColumn get kind => text()();

  /// HTTP verb to replay, e.g. `POST`.
  TextColumn get method => text()();

  /// Request path relative to the Money API base, e.g.
  /// `/accounts/<id>/transactions`.
  TextColumn get path => text()();

  /// JSON request body, stored exactly as it will be sent.
  TextColumn get payload => text()();

  /// Where this row sits in the replay lifecycle.
  TextColumn get status => textEnum<OperationStatus>()();

  /// How many send attempts have been made; drives backoff and diagnostics.
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// Last failure detail, surfaced for [OperationStatus.failed] rows. Null until
  /// a send fails.
  TextColumn get lastError => text().nullable()();

  /// When the operation was first enqueued.
  DateTimeColumn get createdAt => dateTime()();

  /// When the row was last touched (status flip, attempt bump).
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

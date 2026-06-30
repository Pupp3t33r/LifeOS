import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/money/data/money_api.dart';
import '../data/app_database.dart';
import '../data/operation_status.dart';
import '../data/outbox_repository.dart';

/// Drains the [PendingOperations] outbox: replays each queued mutation through
/// the Money [Dio] and retires the row by outcome. Never client-validates and
/// never transforms the payload — it replays `method`/`path`/`payload` verbatim
/// (Money is the source of truth; see apps/wallet/AGENTS.md).
///
/// Outcome policy per operation:
/// - **2xx** → [OperationStatus.synced].
/// - **409 Conflict** → [OperationStatus.synced]. The server already has this
///   client-assigned id (ADR-0003), so the op is effectively applied — a blind
///   replay after an uncertain earlier send is therefore safe.
/// - **other 4xx** (400/403/404/422…) → [OperationStatus.failed]. A request the
///   user must fix; retrying it unchanged can't succeed.
/// - **401/408/429, any 5xx, or no response** (offline, DNS, timeout) →
///   left [OperationStatus.pending] for the next drain. These are transient.
class OutboxDrainer {
  OutboxDrainer(this._outbox, this._dio, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final OutboxRepository _outbox;
  final Dio _dio;
  final DateTime Function() _clock;

  Future<void>? _inFlight;

  /// Replay every queued operation once, oldest first. Safe to call concurrently
  /// and from multiple triggers — overlapping calls coalesce onto the single
  /// in-flight pass. Never throws; every failure is recorded on its row.
  Future<void> drain() {
    return _inFlight ??= _drain().whenComplete(() => _inFlight = null);
  }

  Future<void> _drain() async {
    for (final op in await _outbox.pending()) {
      await _send(op);
    }
  }

  Future<void> _send(PendingOperation op) async {
    // Claim pending rows so a second trigger can't double-send. A row already
    // `syncing` is a stale claim from a drain that died mid-send (crash/kill);
    // re-send it — the server dedups on the client id, so it's safe.
    if (op.status == OperationStatus.pending) {
      final claimed = await _outbox.markSyncing(op.id, now: _clock());
      if (!claimed) return;
    }

    try {
      await _dio.request<dynamic>(
        op.path,
        data: op.payload,
        options: Options(
          method: op.method,
          contentType: Headers.jsonContentType,
        ),
      );
      await _outbox.markSynced(op.id, now: _clock());
    } on DioException catch (e) {
      await _classify(op, e);
    }
  }

  Future<void> _classify(PendingOperation op, DioException e) async {
    final status = e.response?.statusCode;
    final now = _clock();

    if (status == 409) {
      await _outbox.markSynced(op.id, now: now);
      return;
    }

    final transient = status == null || // no response → offline/DNS/timeout
        status == 401 ||
        status == 408 ||
        status == 429 ||
        status >= 500;
    if (transient) {
      await _outbox.releasePending(op.id, error: _describe(e), now: now);
      return;
    }

    await _outbox.markFailed(op.id, error: _describe(e), now: now);
  }

  String _describe(DioException e) {
    final code = e.response?.statusCode;
    final prefix = code != null ? 'HTTP $code' : e.type.name;
    final detail = e.response?.data ?? e.message;
    return detail == null ? prefix : '$prefix: $detail';
  }
}

/// App-lifetime drainer over the local outbox and the Money [Dio].
final outboxDrainerProvider = Provider<OutboxDrainer>(
  (ref) => OutboxDrainer(
    ref.watch(outboxRepositoryProvider),
    ref.watch(moneyApiProvider),
  ),
);

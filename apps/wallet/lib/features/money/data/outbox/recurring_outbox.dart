import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/data/outbox_repository.dart';
import '../../../../app/sync/outbox_drainer.dart';
import '../../domain/recurring/plan_item.dart';
import '../../domain/recurring/recurrence_rule.dart';
import '../../domain/recurring/recurring_line.dart';
import '../../domain/recurring/schedule_line.dart';

/// Money-specific bridge onto the generic outbox for the recurring feature
/// (ADR-0017/0028). Every mutation — create, confirm, skip, cancel — is durably
/// queued and replayed by the shared drainer, exactly like `record_flow`: the local
/// write is the "saved before the server" guarantee, and each op is idempotent on a
/// client-assigned id (a duplicate is a 409 → already applied).
///
/// The drainer replays oldest-first, so a create enqueued before a confirm of one of
/// its occurrences drains in that order — the ordering a future offline occurrence
/// projection would rely on (see `app/sync/README.md`). Occurrence rendering itself
/// still needs the server projection, so a just-created recurring surfaces once its
/// op syncs.
class RecurringOutbox {
  RecurringOutbox(this._outbox, this._drainer);

  final OutboxRepository _outbox;
  final OutboxDrainer _drainer;

  /// Create an **Ongoing** (Live) recurring: a rule + a per-occurrence estimate.
  Future<void> createOngoing({
    required String recurringId,
    required String name,
    required bool isIncome,
    required String currency,
    String? categoryId,
    required RecurrenceRule rule,
    required List<RecurringLineDraft> estimateLines,
    DateTime? now,
  }) {
    final payload = jsonEncode({
      'recurringId': recurringId,
      'name': name,
      'direction': isIncome ? 'in' : 'out',
      'currency': currency,
      'categoryId': categoryId,
      'accountId': null,
      'mode': 'live',
      'rule': rule.toJson(),
      'estimateLines': [for (final x in estimateLines) x.toJson()],
      'items': null,
      'scheduleLines': null,
    });
    return _enqueue(recurringId, 'create_recurring', 'POST', '/recurring', payload, now);
  }

  /// Create a **Payment plan** (Materialized) recurring: priceless items + bare-money
  /// payments (their sum is the plan total; ADR-0029).
  Future<void> createPaymentPlan({
    required String recurringId,
    required String name,
    required bool isIncome,
    required String currency,
    String? categoryId,
    required List<PlanItemDraft> items,
    required List<ScheduleLineDraft> scheduleLines,
    DateTime? now,
  }) {
    final payload = jsonEncode({
      'recurringId': recurringId,
      'name': name,
      'direction': isIncome ? 'in' : 'out',
      'currency': currency,
      'categoryId': categoryId,
      'accountId': null,
      'mode': 'materialized',
      'rule': null,
      'estimateLines': null,
      'items': [for (final x in items) x.toJson()],
      'scheduleLines': [for (final x in scheduleLines) x.toJson()],
    });
    return _enqueue(recurringId, 'create_recurring', 'POST', '/recurring', payload, now);
  }

  /// Confirm an occurrence as paid. [entryId] is the client-assigned id of the
  /// resulting flow (idempotency). Omit [lines] to record the occurrence's expected
  /// breakdown; a Live occurrence may override it fully, a plan payment may carry a
  /// single line as an amount-only adjustment of what was actually paid (ADR-0029).
  Future<void> confirm({
    required String recurringId,
    required String occurrenceRef,
    required String entryId,
    required DateTime occurredAt,
    List<RecurringLineDraft>? lines,
    String? description,
    DateTime? now,
  }) {
    final payload = jsonEncode({
      'entryId': entryId,
      'occurrenceRef': occurrenceRef,
      'occurredAt': occurredAt.toUtc().toIso8601String(),
      'lines': lines == null ? null : [for (final x in lines) x.toJson()],
      'description': description,
    });
    return _enqueue(
      entryId, 'confirm_occurrence', 'POST',
      '/recurring/$recurringId/occurrences/confirm', payload, now);
  }

  /// Skip an occurrence (unpaid, no arrears). Idempotent on the occurrence itself.
  Future<void> skip({
    required String recurringId,
    required String occurrenceRef,
    DateTime? now,
  }) {
    final payload = jsonEncode({'occurrenceRef': occurrenceRef});
    // Deterministic id so a re-skip of the same occurrence replaces its row.
    final id = 'skip_${recurringId}_$occurrenceRef';
    return _enqueue(
      id, 'skip_occurrence', 'POST',
      '/recurring/$recurringId/occurrences/skip', payload, now);
  }

  /// Cancel a recurring (terminal). [refunded] records whether a payment-plan
  /// cancellation carries a refund (ADR-0028 §6); the refund flow itself is separate.
  Future<void> cancel({
    required String recurringId,
    required bool refunded,
    DateTime? now,
  }) {
    final id = 'cancel_$recurringId';
    return _enqueue(
      id, 'cancel_recurring', 'POST',
      '/recurring/$recurringId/cancel?refunded=$refunded', '{}', now);
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

final recurringOutboxProvider = Provider<RecurringOutbox>(
  (ref) => RecurringOutbox(
    ref.watch(outboxRepositoryProvider),
    ref.watch(outboxDrainerProvider),
  ),
);

/// A random RFC-4122 v4 UUID (client-assigned recurring id / entry id / idempotency
/// key). Local because the app pulls in no `uuid` package (mirrors `FlowOutbox`).
String recurringUuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int b) => b.toRadixString(16).padLeft(2, '0');
  final h = bytes.map(hex).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}'
      '-${h.substring(16, 20)}-${h.substring(20)}';
}

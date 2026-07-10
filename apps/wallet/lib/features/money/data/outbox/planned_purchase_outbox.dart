import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/data/outbox_repository.dart';
import '../../../../app/sync/outbox_drainer.dart';
import 'record_flow.dart';

/// Money-specific bridge onto the generic outbox for planned purchases (ADR-0018).
/// Every mutation — add, edit, cancel, pay — is durably queued and replayed by the
/// shared drainer, exactly like `record_flow`: the local write is the "saved before
/// the server" guarantee, and each op is idempotent (a duplicate is a 409 → already
/// applied). Reuses [FlowLineDraft] (positive magnitudes; the server signs a planned
/// purchase's lines negative) and the shared UUID helper.
///
/// The drainer replays oldest-first, so an add enqueued before a pay/edit/cancel of
/// the same entry drains in that order — the pay's endpoint 404s otherwise. Occurrence
/// rendering still needs the server projection, so a just-added planned purchase
/// surfaces once its add op syncs (offline projection is deferred, as for recurring).
class PlannedPurchaseOutbox {
  PlannedPurchaseOutbox(this._outbox, this._drainer);

  final OutboxRepository _outbox;
  final OutboxDrainer _drainer;

  /// Add a planned purchase to period [year]/[month].
  Future<void> add({
    required String entryId,
    required int year,
    required int month,
    required String currency,
    required List<FlowLineDraft> lines,
    String? description,
    DateTime? now,
  }) {
    final payload = jsonEncode({
      'entryId': entryId,
      'currency': currency,
      'description': description,
      'lines': [for (final x in lines) _line(x)],
    });
    return _enqueue(
      entryId, 'add_planned_purchase', 'POST',
      '/months/$year/$month/planned-purchases', payload, now);
  }

  /// Edit an unpaid planned purchase in place. Deterministic op id so a re-edit while
  /// the previous one is still pending replaces it (last-write-wins offline).
  Future<void> edit({
    required String entryId,
    required int year,
    required int month,
    required String currency,
    required List<FlowLineDraft> lines,
    String? description,
    DateTime? now,
  }) {
    final payload = jsonEncode({
      'currency': currency,
      'description': description,
      'lines': [for (final x in lines) _line(x)],
    });
    return _enqueue(
      'edit_planned_$entryId', 'edit_planned_purchase', 'PUT',
      '/months/$year/$month/planned-purchases/$entryId', payload, now);
  }

  /// Cancel a planned purchase (terminal). Deterministic id so a re-cancel is a no-op.
  Future<void> cancel({
    required String entryId,
    required int year,
    required int month,
    DateTime? now,
  }) {
    // plannedEntryId is carried in the payload too, so the optimistic overlay can drop
    // the row before the DELETE drains (the path alone is harder to decode uniformly).
    final payload = jsonEncode({'plannedEntryId': entryId});
    return _enqueue(
      'cancel_planned_$entryId', 'cancel_planned_purchase', 'DELETE',
      '/months/$year/$month/planned-purchases/$entryId', payload, now);
  }

  /// Pay a planned purchase — records a flow that settles it. [flowEntryId] is the
  /// client-assigned id of the resulting flow (idempotency). Omit [amount] to pay the
  /// planned total; pass it to record a different actual (ADR-0018).
  Future<void> pay({
    required String plannedEntryId,
    required String flowEntryId,
    required int year,
    required int month,
    required DateTime occurredAt,
    double? amount,
    String? description,
    DateTime? now,
  }) {
    final payload = jsonEncode({
      'plannedEntryId': plannedEntryId,
      'entryId': flowEntryId,
      'occurredAt': occurredAt.toUtc().toIso8601String(),
      'amount': amount,
      'description': description,
    });
    return _enqueue(
      flowEntryId, 'pay_planned_purchase', 'POST',
      '/months/$year/$month/planned-purchases/$plannedEntryId/pay', payload, now);
  }

  Map<String, dynamic> _line(FlowLineDraft line) => {
        'amount': line.amount,
        'categoryId': line.categoryId,
        'description': line.description,
        'wishlistItemId': line.wishlistItemId,
      };

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

final plannedPurchaseOutboxProvider = Provider<PlannedPurchaseOutbox>(
  (ref) => PlannedPurchaseOutbox(
    ref.watch(outboxRepositoryProvider),
    ref.watch(outboxDrainerProvider),
  ),
);

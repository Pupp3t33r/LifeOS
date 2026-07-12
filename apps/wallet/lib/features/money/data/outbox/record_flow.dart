import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/data/outbox_repository.dart';
import '../../../../app/sync/outbox_drainer.dart';
import '../../domain/month_period.dart';
import '../../domain/unit_dimension.dart';

/// One line of a flow entry as the client sends it: a **positive magnitude**
/// [amount] (the entry's direction supplies the sign server-side), an optional
/// budgeting [categoryId] (ADR-0024), an optional [description], an optional
/// [quantity] + [unitDimension] (ADR-0036 — the count/magnitude and its generic
/// dimension; amount stays the line total), and an optional [wishlistItemId]
/// linking the line to a wishlist want (ADR-0034 — the ref a Board drag carries
/// so the want reads as Planned).
class FlowLineDraft {
  const FlowLineDraft({
    required this.amount,
    this.categoryId,
    this.description,
    this.quantity,
    this.unitDimension,
    this.wishlistItemId,
  });

  final double amount;
  final String? categoryId;
  final String? description;
  final double? quantity;
  final UnitDimension? unitDimension;
  final String? wishlistItemId;
}

/// Money-specific bridge onto the generic outbox: builds a `record_flow` operation
/// (ADR-0016 flow ledger) and durably queues it as `POST /months/{y}/{m}/transactions`
/// with a client-assigned `EntryId` for idempotency (ADR-0003). The period in the
/// path is derived from the actual date + the user's month-start-day, mirroring the
/// server's `MonthPeriod`.
///
/// Returns once the local outbox row is committed — that write *is* the "saved
/// before the server" guarantee. A drain is kicked off but not awaited, so the UI
/// never blocks on the network; the drainer (app/sync) replays it if the send fails.
class FlowOutbox {
  FlowOutbox(this._outbox, this._drainer);

  final OutboxRepository _outbox;
  final OutboxDrainer _drainer;

  Future<void> record({
    required bool isIncome,
    required String currency,
    required DateTime occurredAt,
    required int monthStartDay,
    required List<FlowLineDraft> lines,
    String? description,
    DateTime? now,
  }) async {
    final entryId = _uuidV4();
    final period = containingPeriod(occurredAt, monthStartDay);

    final payload = jsonEncode({
      'entryId': entryId,
      'direction': isIncome ? 'in' : 'out',
      'currency': currency,
      'occurredAt': occurredAt.toUtc().toIso8601String(),
      'description': description,
      'lines': [
        for (final line in lines)
          {
            'amount': line.amount,
            'categoryId': line.categoryId,
            'description': line.description,
            'quantity': line.quantity,
            'unitDimension': line.unitDimension?.wire,
          },
      ],
    });

    await _outbox.enqueue(
      id: entryId,
      kind: 'record_flow',
      method: 'POST',
      path: '/months/${period.year}/${period.month}/transactions',
      payload: payload,
      now: now ?? DateTime.now(),
    );

    // Fire-and-forget: replay happens on the drainer's schedule, not the user's.
    unawaited(_drainer.drain());
  }
}

final flowOutboxProvider = Provider<FlowOutbox>(
  (ref) => FlowOutbox(
    ref.watch(outboxRepositoryProvider),
    ref.watch(outboxDrainerProvider),
  ),
);

/// A random RFC-4122 v4 UUID (= the EntryId / idempotency key). Local because the
/// app pulls in no `uuid` package for a couple of call sites (mirrors
/// PreferencesRepository).
String _uuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1
  String hex(int b) => b.toRadixString(16).padLeft(2, '0');
  final h = bytes.map(hex).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}'
      '-${h.substring(16, 20)}-${h.substring(20)}';
}

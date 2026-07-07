import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/outbox/recurring_outbox.dart';
import '../../domain/recurring/occurrence.dart';
import '../../domain/recurring/recurring_line.dart';

/// Shared occurrence mutations used by both the worklist (one-tap) and the resolve
/// sheets — thin wrappers over [RecurringOutbox] so every call site queues the same
/// idempotent op.

/// Mark an occurrence paid. With no [actualAmount] the server records the occurrence's
/// expected breakdown (Live estimate, or a plan payment's scheduled amount under the
/// plan category). Pass [actualAmount] to record what was really paid — a full-line
/// override for Live, or a single-line amount adjustment for a plan payment (ADR-0029).
/// Dated on the due date.
Future<void> markOccurrencePaidAsPlanned(
  WidgetRef ref, {
  required String recurringId,
  required Occurrence occurrence,
  String? description,
  double? actualAmount,
}) {
  return ref.read(recurringOutboxProvider).confirm(
        recurringId: recurringId,
        occurrenceRef: occurrence.occurrenceRef,
        entryId: recurringUuidV4(),
        occurredAt: occurrence.dueDate,
        lines: actualAmount == null
            ? null
            : [RecurringLineDraft(amount: actualAmount)],
        description: description,
      );
}

/// Skip an occurrence (unpaid, no arrears).
Future<void> skipOccurrence(
  WidgetRef ref, {
  required String recurringId,
  required Occurrence occurrence,
}) {
  return ref.read(recurringOutboxProvider).skip(
        recurringId: recurringId,
        occurrenceRef: occurrence.occurrenceRef,
      );
}

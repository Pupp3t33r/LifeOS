import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/outbox/recurring_outbox.dart';
import '../../domain/recurring/occurrence.dart';

/// Shared occurrence mutations used by both the worklist (one-tap) and the resolve
/// sheets — thin wrappers over [RecurringOutbox] so every call site queues the same
/// idempotent op.

/// Mark an occurrence paid exactly as planned: confirm with no override, so the
/// server records the occurrence's expected lines (Live) or its proportional slice
/// (a plan payment). Dated on the due date.
Future<void> markOccurrencePaidAsPlanned(
  WidgetRef ref, {
  required String recurringId,
  required Occurrence occurrence,
  String? description,
}) {
  return ref.read(recurringOutboxProvider).confirm(
        recurringId: recurringId,
        occurrenceRef: occurrence.occurrenceRef,
        entryId: recurringUuidV4(),
        occurredAt: occurrence.dueDate,
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

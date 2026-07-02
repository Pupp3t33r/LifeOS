import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/auth/auth_controller.dart';
import '../../../app/data/app_database.dart';
import '../../../app/data/operation_status.dart';
import '../../../app/data/outbox_repository.dart';
import '../data/recurring_repository.dart';
import '../domain/recurring/occurrence.dart';
import '../domain/recurring/recurring_payment.dart';
import 'preferences_providers.dart';

/// A `(year, month)` accounting period — the key for the per-period providers.
typedef PeriodKey = ({int year, int month});

/// One occurrence paired with the recurring it belongs to, so the worklist knows the
/// name to show, whether it's a plan (read-only detail) or Ongoing (override), and
/// which recurring to confirm/skip against.
typedef PeriodOccurrence = ({RecurringPayment recurring, Occurrence occurrence});

/// The outbox's pending/syncing rows — re-emits on every change, so the recurring
/// reads below revalidate when a create/confirm/skip/cancel op is queued or drains.
final _pendingRecurringOpsProvider = StreamProvider<List<PendingOperation>>(
  (ref) => ref.watch(outboxRepositoryProvider).watchPending(),
);

/// The caller's recurring definitions (ADR-0017), auth-gated like `categoriesProvider`.
/// Re-fetches whenever the outbox changes, so a just-created recurring appears once
/// its create op drains.
final recurringListProvider = FutureProvider<List<RecurringPayment>>((ref) {
  final auth = ref.watch(authStateProvider).value;
  if (auth == null || !auth.isAuthenticated) {
    return Future.value(const <RecurringPayment>[]);
  }
  ref.watch(_pendingRecurringOpsProvider); // revalidate on outbox change
  return ref.watch(recurringRepositoryProvider).list();
});

/// Every active recurring's occurrences due in [key]'s window, paired with their
/// parent. One fetch per active recurring (N+1, fine for the handful a user has);
/// re-runs when the recurring list or the outbox changes.
final periodOccurrencesProvider =
    FutureProvider.family<List<PeriodOccurrence>, PeriodKey>((ref, key) async {
  final auth = ref.watch(authStateProvider).value;
  if (auth == null || !auth.isAuthenticated) return const <PeriodOccurrence>[];

  final startDay = ref.watch(preferencesProvider).value?.monthStartDay ?? 1;
  final (from, to) = _periodWindow(key.year, key.month, startDay);

  final recurrings = await ref.watch(recurringListProvider.future);
  final repo = ref.watch(recurringRepositoryProvider);

  final result = <PeriodOccurrence>[];
  for (final recurring in recurrings.where((x) => x.isActive)) {
    final occurrences = await repo.occurrences(recurring.id, from: from, to: to);
    for (final occurrence in occurrences) {
      result.add((recurring: recurring, occurrence: occurrence));
    }
  }
  result.sort((a, b) => a.occurrence.dueDate.compareTo(b.occurrence.dueDate));
  return result;
});

/// Occurrence refs the user has just confirmed or skipped but whose op hasn't synced
/// yet — decoded from the outbox so the row leaves the Upcoming list immediately
/// (the confirmed flow lands in Logged, and the server-derived status catches up, on
/// the next revalidate).
final pendingResolvedRefsProvider = Provider<Set<String>>((ref) {
  final ops = ref.watch(_pendingRecurringOpsProvider).value ?? const [];
  final refs = <String>{};
  for (final op in ops) {
    if (op.status == OperationStatus.failed) continue;
    if (op.kind != 'confirm_occurrence' && op.kind != 'skip_occurrence') continue;
    try {
      final ref = (jsonDecode(op.payload) as Map<String, dynamic>)['occurrenceRef'];
      if (ref is String) refs.add(ref);
    } catch (_) {
      // A malformed op must never crash the worklist.
    }
  }
  return refs;
});

/// Unresolved occurrences for [key] — projected on the server and not optimistically
/// resolved locally. This is the Home worklist's "Upcoming" list. Paid occurrences
/// drop out (they show in Logged as flows); skipped ones just vanish.
final upcomingOccurrencesProvider =
    Provider.family<List<PeriodOccurrence>, PeriodKey>((ref, key) {
  final all = ref.watch(periodOccurrencesProvider(key)).value ?? const <PeriodOccurrence>[];
  final resolved = ref.watch(pendingResolvedRefsProvider);
  return all
      .where((x) =>
          x.occurrence.status == OccurrenceStatus.projected &&
          !resolved.contains(x.occurrence.occurrenceRef))
      .toList();
});

/// The calendar window for period `(year, month)` under [startDay] (ADR-0013): from
/// the period's anchor day to the day before the next period's anchor, inclusive.
(DateTime, DateTime) _periodWindow(int year, int month, int startDay) {
  final start = _anchor(year, month, startDay);
  final next = month == 12 ? (year: year + 1, month: 1) : (year: year, month: month + 1);
  final end = _anchor(next.year, next.month, startDay).subtract(const Duration(days: 1));
  return (start, end);
}

DateTime _anchor(int year, int month, int startDay) {
  final daysInMonth = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, startDay < daysInMonth ? startDay : daysInMonth);
}

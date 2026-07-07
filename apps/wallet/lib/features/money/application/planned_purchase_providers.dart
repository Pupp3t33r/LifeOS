import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/auth/auth_controller.dart';
import '../../../app/data/operation_status.dart';
import '../../../app/data/outbox_repository.dart';
import '../data/planned_purchase_repository.dart';
import '../domain/planned_purchase.dart';
import 'recurring_providers.dart' show PeriodKey;

/// The outbox's pending/syncing rows — re-emits on every change, so the planned reads
/// below revalidate when an add/edit/cancel/pay op is queued or drains.
final _pendingPlannedOpsProvider = StreamProvider((ref) =>
    ref.watch(outboxRepositoryProvider).watchPending());

/// The caller's planned purchases for [key] (ADR-0018), auth-gated. Re-fetches whenever
/// the outbox changes, so a just-added planned purchase appears once its add op drains
/// and a paid/cancelled one drops on the next revalidate.
final plannedPurchasesProvider =
    FutureProvider.family<List<PlannedPurchase>, PeriodKey>((ref, key) {
  final auth = ref.watch(authStateProvider).value;
  if (auth == null || !auth.isAuthenticated) {
    return Future.value(const <PlannedPurchase>[]);
  }
  ref.watch(_pendingPlannedOpsProvider); // revalidate on outbox change
  return ref.watch(plannedPurchaseRepositoryProvider).list(key.year, key.month);
});

/// Planned-purchase ids the user has just paid or cancelled but whose op hasn't synced
/// yet — decoded from the outbox so the row leaves the Upcoming list immediately (a
/// paid one reappears in Logged as a flow; a cancelled one just vanishes), the
/// server-derived status catching up on the next revalidate.
final pendingResolvedPlannedProvider = Provider<Set<String>>((ref) {
  final ops = ref.watch(_pendingPlannedOpsProvider).value ?? const [];
  final ids = <String>{};
  for (final op in ops) {
    if (op.status == OperationStatus.failed) continue;
    if (op.kind != 'pay_planned_purchase' && op.kind != 'cancel_planned_purchase') continue;
    try {
      final id = (jsonDecode(op.payload) as Map<String, dynamic>)['plannedEntryId'];
      if (id is String) ids.add(id);
    } catch (_) {
      // A malformed op must never crash the worklist.
    }
  }
  return ids;
});

/// The still-to-buy planned purchases for [key] — server status `planned`, minus any
/// optimistically resolved locally. This is the "Planned" half of the Home worklist's
/// Upcoming section (ADR-0018), alongside recurring occurrences.
final upcomingPlannedProvider =
    Provider.family<List<PlannedPurchase>, PeriodKey>((ref, key) {
  final all = ref.watch(plannedPurchasesProvider(key)).value ?? const <PlannedPurchase>[];
  final resolved = ref.watch(pendingResolvedPlannedProvider);
  return all
      .where((x) =>
          x.status == PlannedPurchaseStatus.planned && !resolved.contains(x.entryId))
      .toList();
});

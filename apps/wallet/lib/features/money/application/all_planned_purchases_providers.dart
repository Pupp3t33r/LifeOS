import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/auth/auth_controller.dart';
import '../../../app/data/outbox_repository.dart';
import '../data/planned_purchase_repository.dart';
import '../domain/period_planned_purchase.dart';

/// The outbox's pending rows — re-emits on every change, so the cross-period read below
/// revalidates when a planned-purchase op is queued or drains.
final _pendingOpsProvider = StreamProvider((ref) =>
    ref.watch(outboxRepositoryProvider).watchPending());

/// The caller's planned purchases across all periods (ADR-0034), auth-gated — the
/// period-agnostic feed for the Plan List "Planned purchases" shelf and the Board.
final allPlannedPurchasesProvider = FutureProvider<List<PeriodPlannedPurchase>>((ref) {
  final auth = ref.watch(authStateProvider).value;
  if (auth == null || !auth.isAuthenticated) {
    return Future.value(const <PeriodPlannedPurchase>[]);
  }
  ref.watch(_pendingOpsProvider); // revalidate on outbox change
  return ref.watch(plannedPurchaseRepositoryProvider).listAll();
});

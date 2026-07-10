import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/auth/auth_controller.dart';
import '../../../app/data/outbox_repository.dart';
import '../data/budget_repository.dart';
import '../domain/period_budget.dart';
import 'recurring_providers.dart' show PeriodKey;

/// The outbox's pending rows — re-emits on change so the budget read revalidates when a
/// put_budget op is queued or drains.
final _pendingBudgetOpsProvider = StreamProvider((ref) =>
    ref.watch(outboxRepositoryProvider).watchPending());

/// The caller's budget for [key] (ADR-0035), auth-gated. Re-fetches whenever the outbox
/// changes, so a just-saved budget reflects once its op drains.
final budgetProvider = FutureProvider.family<PeriodBudget, PeriodKey>((ref, key) {
  final auth = ref.watch(authStateProvider).value;
  if (auth == null || !auth.isAuthenticated) {
    return Future.value(PeriodBudget(
      year: key.year, month: key.month, limits: const [], trackedCategories: const []));
  }
  ref.watch(_pendingBudgetOpsProvider); // revalidate on outbox change
  return ref.watch(budgetRepositoryProvider).get(key.year, key.month);
});

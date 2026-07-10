import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/data/outbox_repository.dart';
import '../../../../app/sync/outbox_drainer.dart';

/// One category limit as the client sends it (ADR-0035): positive magnitude in the
/// display currency.
class BudgetLimitDraft {
  const BudgetLimitDraft({required this.categoryId, required this.amount, required this.currency});

  final String categoryId;
  final double amount;
  final String currency;
}

/// Money-specific bridge onto the generic outbox for the per-period budget (ADR-0035).
/// The Budget view saves the whole record in one PUT (savings target + limits + tracked
/// set); the op id is deterministic per (year, month) so a re-save while the previous is
/// pending replaces it (last-write-wins offline). The upsert is idempotent server-side.
class BudgetOutbox {
  BudgetOutbox(this._outbox, this._drainer);

  final OutboxRepository _outbox;
  final OutboxDrainer _drainer;

  Future<void> put({
    required int year,
    required int month,
    double? savingsTarget,
    String? currency,
    required List<BudgetLimitDraft> limits,
    required List<String> trackedCategories,
    DateTime? now,
  }) async {
    final payload = jsonEncode({
      'savingsTarget': savingsTarget == null ? null : {'amount': savingsTarget, 'currency': currency},
      'limits': [
        for (final l in limits)
          {'categoryId': l.categoryId, 'amount': {'amount': l.amount, 'currency': l.currency}},
      ],
      'trackedCategories': trackedCategories,
    });
    await _outbox.enqueue(
      id: 'put_budget_${year}_$month',
      kind: 'put_budget',
      method: 'PUT',
      path: '/budgets?year=$year&month=$month',
      payload: payload,
      now: now ?? DateTime.now(),
    );
    unawaited(_drainer.drain());
  }
}

final budgetOutboxProvider = Provider<BudgetOutbox>(
  (ref) => BudgetOutbox(
    ref.watch(outboxRepositoryProvider),
    ref.watch(outboxDrainerProvider),
  ),
);

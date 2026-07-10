import 'money.dart';

/// One category's spending limit (Money ADR-0035), display currency.
class BudgetLimit {
  const BudgetLimit({required this.categoryId, required this.amount});

  final String categoryId;
  final Money amount;

  factory BudgetLimit.fromJson(Map<String, dynamic> json) => BudgetLimit(
        categoryId: json['categoryId'] as String,
        amount: Money(
          amount: (json['amount'] as Map<String, dynamic>)['amount'] as num,
          currency: (json['amount'] as Map<String, dynamic>)['currency'] as String,
        ),
      );
}

/// Dart mirror of the Money service's `PeriodBudgetResponse` (ADR-0035): one period's
/// savings target, per-category limits, and the tracked-category opt-in subset. A period
/// with no budget yet reads as an empty default (null target, no limits, none tracked).
class PeriodBudget {
  const PeriodBudget({
    required this.year,
    required this.month,
    required this.limits,
    required this.trackedCategories,
    this.savingsTarget,
  });

  final int year;
  final int month;
  final Money? savingsTarget;
  final List<BudgetLimit> limits;
  final List<String> trackedCategories;

  Money? limitFor(String categoryId) {
    for (final l in limits) {
      if (l.categoryId == categoryId) return l.amount;
    }
    return null;
  }

  bool isTracked(String categoryId) => trackedCategories.contains(categoryId);

  factory PeriodBudget.fromJson(Map<String, dynamic> json) {
    final target = json['savingsTarget'] as Map<String, dynamic>?;
    return PeriodBudget(
      year: json['year'] as int,
      month: json['month'] as int,
      savingsTarget: target == null
          ? null
          : Money(amount: target['amount'] as num, currency: target['currency'] as String),
      limits: [
        for (final x in json['limits'] as List<dynamic>? ?? const [])
          BudgetLimit.fromJson(x as Map<String, dynamic>),
      ],
      trackedCategories: [
        for (final x in json['trackedCategories'] as List<dynamic>? ?? const []) x as String,
      ],
    );
  }
}

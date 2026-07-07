import '../money.dart';
import 'plan_item.dart';
import 'recurrence_rule.dart';
import 'recurring_line.dart';
import 'schedule_line.dart';

/// The two schedule shapes (ADR-0017), named as the UI names them.
enum ScheduleMode {
  /// Rule-computed — "Ongoing" in the UI.
  live,

  /// A finite payment plan — "Payment plan" in the UI.
  materialized,
}

/// Dart mirror of the Money service's `RecurringResponse` (ADR-0017/0028). Holds the
/// definition + lifecycle only; per-occurrence status is computed by the occurrences
/// endpoint. For [ScheduleMode.live], [rule] + [estimateLines] + [estimatedAmount]
/// are set; for [ScheduleMode.materialized], [items] (the plan's priceless contents) +
/// [scheduleLines] (bare-money payments; their sum is the plan total) are set instead.
class RecurringPayment {
  const RecurringPayment({
    required this.id,
    required this.name,
    required this.isIncome,
    required this.currency,
    required this.mode,
    required this.estimateLines,
    required this.items,
    required this.scheduleLines,
    required this.isActive,
    this.categoryId,
    this.accountId,
    this.rule,
    this.estimatedAmount,
  });

  final String id;
  final String name;
  final bool isIncome;
  final String currency;
  final ScheduleMode mode;
  final String? categoryId;
  final String? accountId;

  /// Live only — the recurrence rule and the per-occurrence estimate.
  final RecurrenceRule? rule;
  final List<RecurringLine> estimateLines;
  final Money? estimatedAmount;

  /// Materialized only — the plan's priceless line-item contents and its bare-money
  /// payments (the payments' sum is the plan total; items carry no cost).
  final List<PlanItem> items;
  final List<ScheduleLine> scheduleLines;

  final bool isActive;

  factory RecurringPayment.fromJson(Map<String, dynamic> json) {
    List<RecurringLine> lines(String key) => [
          for (final x in (json[key] as List<dynamic>? ?? const []))
            RecurringLine.fromJson(x as Map<String, dynamic>),
        ];
    final estimated = json['estimatedAmount'] as Map<String, dynamic>?;
    return RecurringPayment(
      id: json['id'] as String,
      name: json['name'] as String,
      isIncome: json['direction'] == 'in',
      currency: json['currency'] as String,
      mode: json['mode'] == 'materialized' ? ScheduleMode.materialized : ScheduleMode.live,
      categoryId: json['categoryId'] as String?,
      accountId: json['accountId'] as String?,
      rule: RecurrenceRule.fromJson(json['rule'] as Map<String, dynamic>?),
      estimateLines: lines('estimateLines'),
      estimatedAmount: estimated == null
          ? null
          : Money(amount: estimated['amount'] as num, currency: estimated['currency'] as String),
      items: [
        for (final x in (json['items'] as List<dynamic>? ?? const []))
          PlanItem.fromJson(x as Map<String, dynamic>),
      ],
      scheduleLines: [
        for (final x in (json['scheduleLines'] as List<dynamic>? ?? const []))
          ScheduleLine.fromJson(x as Map<String, dynamic>),
      ],
      isActive: json['status'] == 'active',
    );
  }
}

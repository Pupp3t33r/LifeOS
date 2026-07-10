import 'money.dart';
import 'period_flows.dart';
import 'planned_purchase.dart';

/// Dart mirror of the Money service's `PeriodPlannedPurchaseResponse` (ADR-0018/0034) —
/// a planned purchase carrying its [year]/[month], the cross-period shape the Plan List
/// and Board read. Amounts are signed negative (spending). [deadline] is the optional
/// "buy by" date; [status] is planned or paid (with the settling actuals when paid).
class PeriodPlannedPurchase {
  const PeriodPlannedPurchase({
    required this.entryId,
    required this.year,
    required this.month,
    required this.lines,
    required this.total,
    required this.addedAt,
    required this.status,
    this.description,
    this.paidTotal,
    this.paidOn,
    this.deadline,
  });

  final String entryId;
  final int year;
  final int month;
  final List<FlowLine> lines;
  final Money total;
  final DateTime addedAt;
  final PlannedPurchaseStatus status;
  final String? description;
  final Money? paidTotal;
  final DateTime? paidOn;
  final DateTime? deadline;

  factory PeriodPlannedPurchase.fromJson(Map<String, dynamic> json) {
    Money money(Map<String, dynamic> m) =>
        Money(amount: m['amount'] as num, currency: m['currency'] as String);
    final paidTotal = json['paidTotal'] as Map<String, dynamic>?;
    final paidOn = json['paidOn'] as String?;
    final deadline = json['deadline'] as String?;
    return PeriodPlannedPurchase(
      entryId: json['entryId'] as String,
      year: json['year'] as int,
      month: json['month'] as int,
      lines: [
        for (final x in json['lines'] as List<dynamic>)
          FlowLine.fromJson(x as Map<String, dynamic>),
      ],
      total: money(json['total'] as Map<String, dynamic>),
      addedAt: DateTime.parse(json['addedAt'] as String),
      status: json['status'] == 'paid'
          ? PlannedPurchaseStatus.paid
          : PlannedPurchaseStatus.planned,
      description: json['description'] as String?,
      paidTotal: paidTotal == null ? null : money(paidTotal),
      paidOn: paidOn == null ? null : DateTime.parse(paidOn),
      deadline: deadline == null ? null : DateTime.parse(deadline),
    );
  }
}

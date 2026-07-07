import 'money.dart';
import 'period_flows.dart';

/// Where a planned purchase stands (ADR-0018): still [planned] (an intention that
/// lowers projected savings), or [paid] (a settling flow exists — it now reads as a
/// real actual in the Logged ledger).
enum PlannedPurchaseStatus { planned, paid }

/// Dart mirror of the Money service's `PlannedPurchaseResponse` — one planned purchase
/// on an accounting period (ADR-0018): a line-itemed intention to buy this month.
/// [total] and each line's amount are **signed negative** (spending), so the entry
/// reads as a plain Σ (ADR-0026). When [status] is [PlannedPurchaseStatus.paid],
/// [paidTotal]/[paidOn] carry the settling flow's actuals (which may differ from the
/// planned [total] if the amount was adjusted at pay).
class PlannedPurchase {
  const PlannedPurchase({
    required this.entryId,
    required this.lines,
    required this.total,
    required this.addedAt,
    required this.status,
    this.description,
    this.paidTotal,
    this.paidOn,
  });

  final String entryId;
  final List<FlowLine> lines;
  final Money total;
  final DateTime addedAt;
  final PlannedPurchaseStatus status;
  final String? description;
  final Money? paidTotal;
  final DateTime? paidOn;

  factory PlannedPurchase.fromJson(Map<String, dynamic> json) {
    Money money(Map<String, dynamic> m) =>
        Money(amount: m['amount'] as num, currency: m['currency'] as String);
    final paidTotal = json['paidTotal'] as Map<String, dynamic>?;
    final paidOn = json['paidOn'] as String?;
    return PlannedPurchase(
      entryId: json['entryId'] as String,
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
    );
  }
}

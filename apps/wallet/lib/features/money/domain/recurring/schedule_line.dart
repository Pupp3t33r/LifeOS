import '../money.dart';
import 'date_only.dart';

/// A Materialized plan's scheduled payment (ADR-0028): bare money on a due date. The
/// client-assigned [lineId] is the stable **occurrence reference** used when
/// confirming/skipping. [amount] is signed in a response; a request instead sends a
/// positive magnitude (the plan's direction supplies the sign). The plan's line-item
/// *contents* live on the payment's `Items`, not here.
class ScheduleLine {
  const ScheduleLine({required this.lineId, required this.dueDate, required this.amount});

  final String lineId;
  final DateTime dueDate;
  final Money amount;

  factory ScheduleLine.fromJson(Map<String, dynamic> json) => ScheduleLine(
        lineId: json['lineId'] as String,
        dueDate: parseDateOnly(json['dueDate'] as String),
        amount: Money(
          amount: (json['amount'] as Map<String, dynamic>)['amount'] as num,
          currency: (json['amount'] as Map<String, dynamic>)['currency'] as String,
        ),
      );
}

/// A scheduled payment as the client authors it (ADR-0028): a client-assigned
/// [lineId], a [dueDate], and a positive-magnitude [amount]. Serialized as
/// `ScheduleLineRequest`.
class ScheduleLineDraft {
  const ScheduleLineDraft({required this.lineId, required this.dueDate, required this.amount});

  final String lineId;
  final DateTime dueDate;
  final double amount;

  Map<String, dynamic> toJson() => {
        'lineId': lineId,
        'dueDate': dateOnlyString(dueDate),
        'amount': amount,
      };
}

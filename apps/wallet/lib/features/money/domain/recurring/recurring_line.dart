import '../money.dart';

/// Dart mirror of the Money service's `Line` (ADR-0019/0026) as it appears in a
/// recurring payment's estimate/items and in an occurrence's breakdown. [amount] is
/// **signed** (negative = out, positive = in). Requests instead carry a positive
/// magnitude (see `RecurringLineDraft`); the payment's direction supplies the sign
/// server-side, matching the flow-recording contract.
class RecurringLine {
  const RecurringLine({required this.amount, this.description, this.categoryId});

  final Money amount;
  final String? description;
  final String? categoryId;

  factory RecurringLine.fromJson(Map<String, dynamic> json) => RecurringLine(
        amount: Money(
          amount: (json['amount'] as Map<String, dynamic>)['amount'] as num,
          currency: (json['amount'] as Map<String, dynamic>)['currency'] as String,
        ),
        description: json['description'] as String?,
        categoryId: json['categoryId'] as String?,
      );
}

/// One line as the client authors it: a positive magnitude [amount], an optional
/// budgeting [categoryId], and an optional [description]. The direction sets the
/// sign server-side. Serialized as `RecurringLineRequest`.
class RecurringLineDraft {
  const RecurringLineDraft({required this.amount, this.categoryId, this.description});

  final double amount;
  final String? categoryId;
  final String? description;

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'categoryId': categoryId,
        'description': description,
      };
}

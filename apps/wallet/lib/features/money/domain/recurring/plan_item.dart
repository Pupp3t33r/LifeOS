import '../money.dart';

/// Dart mirror of the Money service's `PlanItem` (ADR-0029) — a Materialized plan's
/// priceless contents. An item says *what* the plan buys and carries no cost:
/// [referenceValue] is an optional informational figure (MSRP-style, never a cost that
/// sums to the payments), [categoryId] the budgeting category, [wishlistItemId] the
/// Phase-2 link. The plan's real total is its payments.
class PlanItem {
  const PlanItem({this.description, this.referenceValue, this.categoryId, this.wishlistItemId});

  final String? description;
  final Money? referenceValue;
  final String? categoryId;
  final String? wishlistItemId;

  factory PlanItem.fromJson(Map<String, dynamic> json) {
    final ref = json['referenceValue'] as Map<String, dynamic>?;
    return PlanItem(
      description: json['description'] as String?,
      referenceValue: ref == null
          ? null
          : Money(amount: ref['amount'] as num, currency: ref['currency'] as String),
      categoryId: json['categoryId'] as String?,
      wishlistItemId: json['wishlistItemId'] as String?,
    );
  }
}

/// A plan item as the client authors it (ADR-0029): priceless contents. [referenceValue]
/// is an optional positive magnitude, stored in the plan's currency and informational
/// only. Serialized as `PlanItemRequest`.
class PlanItemDraft {
  const PlanItemDraft({this.description, this.referenceValue, this.categoryId, this.wishlistItemId});

  final String? description;
  final double? referenceValue;
  final String? categoryId;
  final String? wishlistItemId;

  Map<String, dynamic> toJson() => {
        'description': description,
        'referenceValue': referenceValue,
        'categoryId': categoryId,
        'wishlistItemId': wishlistItemId,
      };
}

import 'unit_dimension.dart';

/// One chip in a want's schedule — the read composition over the planned-purchase
/// store (Money ADR-0034 §"Board horizon"). A chip is one (month, paid-state,
/// unit-dimension) group with its summed quantity. The window is current + future
/// only — paid history lives in Activity, so chips never accumulate.
///
/// Rides the wire as `WishlistScheduleChipResponse`: `{year, month, paid,
/// unitDimension, quantity}` where `unitDimension` is an int and `paid` is a bool.
class WishlistScheduleChip {
  const WishlistScheduleChip({
    required this.year,
    required this.month,
    required this.paid,
    required this.unitDimension,
    required this.quantity,
  });

  final int year;
  final int month;
  final bool paid;
  final UnitDimension unitDimension;
  final double quantity;

  factory WishlistScheduleChip.fromJson(Map<String, dynamic> json) =>
      WishlistScheduleChip(
        year: json['year'] as int,
        month: json['month'] as int,
        paid: json['paid'] as bool,
        unitDimension: UnitDimension.fromWire(json['unitDimension']) ??
            UnitDimension.pieces,
        quantity: (json['quantity'] as num).toDouble(),
      );
}

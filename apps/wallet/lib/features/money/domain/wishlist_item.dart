import 'money.dart';

/// Whether a want can be committed once or repeatedly (Money ADR-0034). A [once] want
/// leaves the Board try-on tray when planned/financed; a [reusable] one stays and each
/// drag spawns an independent planned purchase.
enum WishlistRecurrence {
  once,
  reusable;

  static WishlistRecurrence fromWire(String? value) =>
      value == 'reusable' ? WishlistRecurrence.reusable : WishlistRecurrence.once;

  String get wire => this == WishlistRecurrence.reusable ? 'reusable' : 'once';
}

/// A want's derived commitment state (Money ADR-0034). The Board tray shows [idle] wants
/// (plus all reusables); [planned] is on a month, [financed] is inside a payment plan,
/// [bought] is a settled single purchase.
enum WishlistCommitment {
  idle,
  planned,
  financed,
  bought;

  static WishlistCommitment fromWire(String? value) => switch (value) {
        'planned' => WishlistCommitment.planned,
        'financed' => WishlistCommitment.financed,
        'bought' => WishlistCommitment.bought,
        _ => WishlistCommitment.idle,
      };
}

/// Dart mirror of the Money service's `WishlistItemResponse` (ADR-0022/0034): a want
/// document zipped with its derived commitment [status]. [estimate] is optional
/// (ADR-0030). Context fields are populated only for their status ([plannedYear]/
/// [plannedMonth] when planned, [planId] when financed, [boughtDate] when bought).
class WishlistItem {
  const WishlistItem({
    required this.id,
    required this.recurrence,
    required this.status,
    this.name,
    this.notes,
    this.estimate,
    this.packageId,
    this.plannedYear,
    this.plannedMonth,
    this.planId,
    this.boughtDate,
  });

  final String id;
  final WishlistRecurrence recurrence;
  final WishlistCommitment status;
  final String? name;
  final String? notes;
  final Money? estimate;
  final String? packageId;
  final int? plannedYear;
  final int? plannedMonth;
  final String? planId;
  final DateTime? boughtDate;

  /// True when the tray should show this want: idle, or reusable regardless of state
  /// (Money ADR-0034 / Wallet ADR-0005 §9).
  bool get isTrayEligible =>
      recurrence == WishlistRecurrence.reusable || status == WishlistCommitment.idle;

  factory WishlistItem.fromJson(Map<String, dynamic> json) {
    final estimate = json['estimate'] as Map<String, dynamic>?;
    final bought = json['boughtDate'] as String?;
    return WishlistItem(
      id: json['id'] as String,
      recurrence: WishlistRecurrence.fromWire(json['recurrence'] as String?),
      status: WishlistCommitment.fromWire(json['status'] as String?),
      name: json['name'] as String?,
      notes: json['notes'] as String?,
      estimate: estimate == null
          ? null
          : Money(amount: estimate['amount'] as num, currency: estimate['currency'] as String),
      packageId: json['packageId'] as String?,
      plannedYear: json['plannedYear'] as int?,
      plannedMonth: json['plannedMonth'] as int?,
      planId: json['planId'] as String?,
      boughtDate: bought == null ? null : DateTime.parse(bought),
    );
  }
}

/// Dart mirror of `PackageResponse` (ADR-0022) — a named grouping of wants.
class WishlistPackage {
  const WishlistPackage({required this.id, required this.name});

  final String id;
  final String name;

  factory WishlistPackage.fromJson(Map<String, dynamic> json) =>
      WishlistPackage(id: json['id'] as String, name: json['name'] as String);
}

/// The owner's whole wishlist (`WishlistResponse`): items (each with derived status) and
/// packages.
class Wishlist {
  const Wishlist({required this.items, required this.packages});

  final List<WishlistItem> items;
  final List<WishlistPackage> packages;

  factory Wishlist.fromJson(Map<String, dynamic> json) => Wishlist(
        items: [
          for (final x in json['items'] as List<dynamic>? ?? const [])
            WishlistItem.fromJson(x as Map<String, dynamic>),
        ],
        packages: [
          for (final x in json['packages'] as List<dynamic>? ?? const [])
            WishlistPackage.fromJson(x as Map<String, dynamic>),
        ],
      );
}

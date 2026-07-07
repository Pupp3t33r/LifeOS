import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/planned_purchase.dart';
import 'planned_purchase_providers.dart';
import 'recurring_providers.dart';

/// One row of the Home worklist's **Upcoming** section — a not-yet-a-flow item the
/// user resolves this period (ADR-0002). Either a recurring occurrence (confirm/skip)
/// or a planned purchase (buy/edit/cancel); the tile picks its affordances by type.
sealed class UpcomingItem {
  const UpcomingItem();

  /// The date the row sorts by, or null when the item has none (a planned purchase
  /// belongs to its period, not a day) — undated items sort after dated ones.
  DateTime? get dueDate;
}

class UpcomingOccurrenceItem extends UpcomingItem {
  const UpcomingOccurrenceItem(this.value);

  final PeriodOccurrence value;

  @override
  DateTime? get dueDate => value.occurrence.dueDate;
}

class UpcomingPlannedItem extends UpcomingItem {
  const UpcomingPlannedItem(this.value);

  final PlannedPurchase value;

  @override
  DateTime? get dueDate => null;
}

/// The composed Upcoming worklist for [key]: recurring occurrences (ADR-0017) and
/// planned purchases (ADR-0018) intermixed, dated items first by due date, then the
/// undated planned purchases (newest-added first, as their provider yields them).
final upcomingItemsProvider =
    Provider.family<List<UpcomingItem>, PeriodKey>((ref, key) {
  final occurrences = ref.watch(upcomingOccurrencesProvider(key));
  final planned = ref.watch(upcomingPlannedProvider(key));

  final items = <UpcomingItem>[
    for (final x in occurrences) UpcomingOccurrenceItem(x),
    for (final x in planned) UpcomingPlannedItem(x),
  ];
  items.sort((a, b) {
    final ad = a.dueDate;
    final bd = b.dueDate;
    if (ad != null && bd != null) return ad.compareTo(bd);
    if (ad != null) return -1;
    if (bd != null) return 1;
    return 0;
  });
  return items;
});

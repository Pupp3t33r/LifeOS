import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/calm_tokens.dart';
import '../../application/all_planned_purchases_providers.dart';
import '../../application/preferences_providers.dart';
import '../../application/recurring_providers.dart';
import '../../application/wishlist_providers.dart';
import '../../data/outbox/planned_purchase_outbox.dart';
import '../../data/outbox/record_flow.dart';
import '../../domain/planned_purchase.dart';
import '../../domain/recurring/recurring_payment.dart';
import '../../domain/wishlist_item.dart';
import '../../../../shared/uuid.dart';
import '../recurring/recurring_shared.dart' show formatMagnitude;

const List<String> _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// The **Board** view (Wallet ADR-0005 §4) — the try-on timeline. A forward run of month
/// columns, each showing its committed weight (planned purchases + payment-plan
/// installments), and a tray of idle wishlist wants. Drag a want onto a month to plan it
/// — the drop is the commit (a planned purchase referencing the want, ADR-0034), no
/// dialog. The month window is derived: the current year shows this month → December, any
/// future year all twelve; only the year is chosen.
class PlanBoardView extends ConsumerStatefulWidget {
  const PlanBoardView({super.key});

  @override
  ConsumerState<PlanBoardView> createState() => _PlanBoardViewState();
}

class _PlanBoardViewState extends ConsumerState<PlanBoardView> {
  int? _year;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    _year ??= now.year;
    final year = _year!;
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);

    final firstMonth = year == now.year ? now.month : 1;
    final weights = _committedByMonth(year);
    final tray = ref.watch(wishlistTrayProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _yearBar(theme, tokens, year, now.year),
        SizedBox(
          height: 168,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (var m = firstMonth; m <= 12; m++)
                _MonthColumn(
                  year: year,
                  month: m,
                  weight: weights[m] ?? 0,
                  currency: _currency(),
                  onAccept: (want) => _plan(want, year, m),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text('Wishlist', style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text('drag a want onto a month',
                  style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted)),
            ],
          ),
        ),
        Expanded(
          child: tray.isEmpty
              ? Center(
                  child: Text('No wants to plan — add some on the Wishlist tab.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: tokens.muted)),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [for (final want in tray) _WantChip(want)],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _yearBar(ThemeData theme, CalmTokens tokens, int year, int currentYear) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: year > currentYear ? () => setState(() => _year = year - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('$year', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          IconButton(
            onPressed: () => setState(() => _year = year + 1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  String _currency() => ref.read(preferencesProvider).value?.displayCurrency ?? 'USD';

  /// Committed weight per month for [year] (Wallet ADR-0005 §4): magnitudes of planned
  /// purchases + payment-plan installments due that month. Ongoing occurrences are
  /// excluded for now (they need per-recurring occurrence expansion).
  Map<int, double> _committedByMonth(int year) {
    final result = <int, double>{};
    final planned = ref.watch(allPlannedPurchasesProvider).value ?? const [];
    for (final p in planned) {
      if (p.year == year && p.status == PlannedPurchaseStatus.planned) {
        result[p.month] = (result[p.month] ?? 0) + p.total.amount.abs();
      }
    }
    final recurrings = ref.watch(recurringListProvider).value ?? const [];
    for (final r in recurrings.where((x) => x.isActive && x.mode == ScheduleMode.materialized)) {
      for (final line in r.scheduleLines) {
        if (line.dueDate.year == year) {
          result[line.dueDate.month] =
              (result[line.dueDate.month] ?? 0) + line.amount.amount.abs();
        }
      }
    }
    return result;
  }

  Future<void> _plan(WishlistItem want, int year, int month) async {
    final currency = want.estimate?.currency ?? _currency();
    final amount = want.estimate?.amount.toDouble() ?? 0;
    await ref.read(plannedPurchaseOutboxProvider).add(
          entryId: newUuidV4(),
          year: year,
          month: month,
          currency: currency,
          description: want.name,
          lines: [
            FlowLineDraft(
              amount: amount,
              description: want.name,
              wishlistItemId: want.id,
            ),
          ],
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Planned ${want.name ?? 'want'} for ${_monthNames[month - 1]} $year')),
    );
  }
}

class _MonthColumn extends StatelessWidget {
  const _MonthColumn({
    required this.year,
    required this.month,
    required this.weight,
    required this.currency,
    required this.onAccept,
  });

  final int year;
  final int month;
  final double weight;
  final String currency;
  final ValueChanged<WishlistItem> onAccept;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    return DragTarget<WishlistItem>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidate, rejected) {
        final hot = candidate.isNotEmpty;
        return Container(
          width: 128,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: hot ? tokens.sage.withValues(alpha: 0.16) : tokens.surface,
            borderRadius: BorderRadius.circular(CalmTokens.radiusMd),
            border: Border.all(color: hot ? tokens.sage : tokens.line, width: hot ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_monthNames[month - 1]} $year',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('committed', style: theme.textTheme.labelSmall?.copyWith(color: tokens.muted)),
              Text(
                weight == 0 ? '—' : '−${formatMagnitude(weight, currency)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: weight == 0 ? tokens.muted : tokens.ink,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WantChip extends StatelessWidget {
  const _WantChip(this.want);

  final WishlistItem want;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    final label = want.name ?? 'Want';
    final estimate = want.estimate;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
        border: Border.all(color: tokens.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            want.recurrence == WishlistRecurrence.reusable ? Icons.repeat : Icons.bookmark_outline,
            size: 16,
            color: tokens.clay,
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (estimate != null) ...[
            const SizedBox(width: 6),
            Text(formatMagnitude(estimate.amount, estimate.currency),
                style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted)),
          ],
        ],
      ),
    );

    return Draggable<WishlistItem>(
      data: want,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(opacity: 0.9, child: chip),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: chip),
      child: chip,
    );
  }
}

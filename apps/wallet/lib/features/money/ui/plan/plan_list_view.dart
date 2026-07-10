import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/calm_tokens.dart';
import '../../application/all_planned_purchases_providers.dart';
import '../../application/recurring_providers.dart';
import '../../application/selected_period_providers.dart';
import '../../domain/period_planned_purchase.dart';
import '../../domain/planned_purchase.dart';
import '../../domain/recurring/recurring_payment.dart';
import '../recurring/create_ongoing_sheet.dart';
import '../recurring/create_payment_plan_sheet.dart';
import '../recurring/create_planned_purchase_sheet.dart';
import '../recurring/recurring_shared.dart' show formatMagnitude, formatSigned;

const List<String> _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// The **List** view (Wallet ADR-0005 §3) — the definitions library. Grouped, editable
/// shelves for the durable planning objects: **Ongoing** (Live recurring), **Payment
/// plans** (Materialized), and **Planned purchases** (cross-period). Create lives here
/// (each shelf's `+ New`). Period-agnostic: it lists definitions and the forward horizon,
/// not one month.
class PlanListView extends ConsumerWidget {
  const PlanListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurrings = ref.watch(recurringListProvider);
    final planned = ref.watch(allPlannedPurchasesProvider);
    final active = ref.watch(activePeriodProvider);

    final ongoing = (recurrings.value ?? const [])
        .where((x) => x.isActive && x.mode == ScheduleMode.live)
        .toList();
    final plans = (recurrings.value ?? const [])
        .where((x) => x.isActive && x.mode == ScheduleMode.materialized)
        .toList();
    final buys = (planned.value ?? const [])
        .where((x) => x.status == PlannedPurchaseStatus.planned)
        .toList()
      ..sort((a, b) => (a.year * 12 + a.month).compareTo(b.year * 12 + b.month));

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      children: [
        _Shelf(
          title: 'Ongoing',
          subtitle: 'Repeats until you stop it',
          onNew: () => showCreateOngoing(context),
          emptyLabel: 'No ongoing payments yet',
          children: [for (final r in ongoing) _OngoingRow(r)],
        ),
        _Shelf(
          title: 'Payment plans',
          subtitle: 'One purchase, paid over a set of payments',
          onNew: () => showCreatePaymentPlan(context),
          emptyLabel: 'No payment plans yet',
          children: [for (final r in plans) _PlanRow(r)],
        ),
        _Shelf(
          title: 'Planned purchases',
          subtitle: 'Things you plan to buy, by month',
          onNew: () =>
              showCreatePlannedPurchase(context, year: active.year, month: active.month),
          emptyLabel: 'Nothing planned yet',
          children: [for (final p in buys) _PlannedRow(p)],
        ),
      ],
    );
  }
}

class _Shelf extends StatelessWidget {
  const _Shelf({
    required this.title,
    required this.subtitle,
    required this.onNew,
    required this.children,
    required this.emptyLabel,
  });

  final String title;
  final String subtitle;
  final VoidCallback onNew;
  final List<Widget> children;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 0, 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                      Text(subtitle, style: theme.textTheme.bodySmall
                          ?.copyWith(color: tokens.muted)),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: onNew,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New'),
                ),
              ],
            ),
          ),
          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 0, 4),
              child: Text(emptyLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(color: tokens.muted)),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(CalmTokens.radiusMd),
                border: Border.all(color: tokens.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(children: _withDividers(children)),
            ),
        ],
      ),
    );
  }

  List<Widget> _withDividers(List<Widget> rows) => [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          rows[i],
        ],
      ];
}

class _OngoingRow extends StatelessWidget {
  const _OngoingRow(this.recurring);

  final RecurringPayment recurring;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    final amount = recurring.estimatedAmount;
    return ListTile(
      leading: Icon(Icons.autorenew, color: tokens.sage),
      title: Text(recurring.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: const Text('Ongoing'),
      trailing: amount == null
          ? null
          : Text(
              // estimatedAmount is Σ signed estimate lines (negative for spending), so
              // render it directly — don't re-apply the direction.
              formatSigned(amount.amount, amount.currency),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: amount.amount >= 0 ? tokens.sage : tokens.ink,
              ),
            ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow(this.recurring);

  final RecurringPayment recurring;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    final count = recurring.scheduleLines.length;
    final total = recurring.scheduleLines.fold<num>(0, (sum, x) => sum + x.amount.amount);
    return ListTile(
      leading: Icon(Icons.receipt_long_outlined, color: tokens.clay),
      title: Text(recurring.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('$count payment${count == 1 ? '' : 's'}'),
      trailing: Text(
        '−${formatMagnitude(total, recurring.currency)}',
        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PlannedRow extends StatelessWidget {
  const _PlannedRow(this.planned);

  final PeriodPlannedPurchase planned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    final label = '${_monthNames[planned.month - 1]} ${planned.year}';
    final deadline = planned.deadline;
    return ListTile(
      leading: Icon(Icons.shopping_bag_outlined, color: tokens.clay),
      title: Text(planned.description ?? 'Planned purchase',
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Row(
        children: [
          Text(label),
          if (deadline != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: tokens.clay.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
              ),
              child: Text(
                'by ${_monthNames[deadline.month - 1]} ${deadline.day}',
                style: theme.textTheme.labelSmall?.copyWith(color: tokens.clay),
              ),
            ),
          ],
        ],
      ),
      trailing: Text(
        formatSigned(planned.total.amount, planned.total.currency),
        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

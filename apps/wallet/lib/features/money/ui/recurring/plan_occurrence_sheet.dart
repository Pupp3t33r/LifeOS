import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/calm_tokens.dart';
import '../../application/categories_providers.dart';
import '../../data/outbox/recurring_outbox.dart';
import '../../domain/category.dart';
import '../../domain/recurring/occurrence.dart';
import '../../domain/recurring/recurring_payment.dart';
import 'occurrence_actions.dart';
import 'recurring_shared.dart';
import 'sheet_container.dart';

/// The **Payment plan** resolve sheet (design/recurring · resolve): tapping a plan
/// installment's row body opens this *read-only* detail — the amount is the plan's
/// server-computed slice and can't be overridden (ADR-0028). It shows what the
/// payment covers + plan progress, and hosts the actions a plan needs a home for:
/// Mark paid, Skip, and Cancel plan (with a refund / no-refund choice).
Future<void> showPlanOccurrence(
  BuildContext context,
  RecurringPayment recurring,
  Occurrence occurrence,
) =>
    showMoneySheet(
      context,
      (bottomSheet) => _PlanOccurrenceSheet(
        bottomSheet: bottomSheet,
        recurring: recurring,
        occurrence: occurrence,
      ),
    );

class _PlanOccurrenceSheet extends ConsumerWidget {
  const _PlanOccurrenceSheet({
    required this.bottomSheet,
    required this.recurring,
    required this.occurrence,
  });

  final bool bottomSheet;
  final RecurringPayment recurring;
  final Occurrence occurrence;

  String get _currency => occurrence.expectedAmount.currency;

  /// This payment's position in the plan (1-based) and the plan's payment count,
  /// ordered as the server orders them (due date, then line id).
  (int, int) get _progress {
    final ordered = [...recurring.scheduleLines]..sort((a, b) {
        final byDate = a.dueDate.compareTo(b.dueDate);
        return byDate != 0 ? byDate : a.lineId.compareTo(b.lineId);
      });
    final index = ordered.indexWhere((x) => x.lineId == occurrence.occurrenceRef);
    return (index < 0 ? 1 : index + 1, ordered.length);
  }

  Future<void> _markPaid(BuildContext context, WidgetRef ref) async {
    await markOccurrencePaidAsPlanned(
        ref, recurringId: recurring.id, occurrence: occurrence, description: recurring.name);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _skip(BuildContext context, WidgetRef ref) async {
    await skipOccurrence(ref, recurringId: recurring.id, occurrence: occurrence);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _cancelPlan(BuildContext context, WidgetRef ref) async {
    final refunded = await _askRefund(context);
    if (refunded == null) return;
    await ref.read(recurringOutboxProvider).cancel(recurringId: recurring.id, refunded: refunded);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final nameById = {for (final c in categories) c.id: c.name};
    final (k, n) = _progress;

    return SheetContainer(
      bottomSheet: bottomSheet,
      title: '▤ ${recurring.name}',
      icon: null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Payment $k of $n · Payment plan',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: 12),

          // Locked amount — the plan's slice, no override.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(CalmTokens.radiusMd),
            ),
            child: Row(
              children: [
                Text(
                  formatSigned(occurrence.expectedAmount.amount, _currency),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontFamily: CalmTokens.fontDisplay,
                    fontWeight: FontWeight.w700,
                    color: recurring.isIncome ? tokens.sageDeep : theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Icon(Icons.lock_outline, size: 15, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: 5),
                Text('set by the plan',
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Text('WHAT IT COVERS',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                fontWeight: FontWeight.w700, letterSpacing: 1.0,
              )),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(CalmTokens.radiusSm),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < occurrence.lines.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: theme.colorScheme.outline),
                  _CoversRow(
                    label: occurrence.lines[i].description ??
                        nameById[occurrence.lines[i].categoryId] ??
                        'Item',
                    sub: nameById[occurrence.lines[i].categoryId],
                    amount: formatSigned(occurrence.lines[i].amount.amount, _currency),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          _PlanButton(
            label: 'Mark paid',
            filled: true,
            onTap: () => _markPaid(context, ref),
          ),
          const SizedBox(height: 8),
          _PlanButton(label: 'Skip this one', filled: false, onTap: () => _skip(context, ref)),
          const SizedBox(height: 2),
          Center(
            child: TextButton(
              onPressed: () => _cancelPlan(context, ref),
              child: Text('Cancel plan · refund or no refund',
                  style: theme.textTheme.bodySmall?.copyWith(color: tokens.clay, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

/// The refund / no-refund choice on cancelling a plan (ADR-0028 §6). Returns true
/// (refund), false (no refund), or null if dismissed.
Future<bool?> _askRefund(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Cancel plan?'),
      content: const Text(
        'Future payments stop. Did this cancellation come with a refund?',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Keep plan')),
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('No refund')),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('With refund')),
      ],
    ),
  );
}

class _CoversRow extends StatelessWidget {
  const _CoversRow({required this.label, required this.amount, this.sub});

  final String label;
  final String? sub;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(label, style: theme.textTheme.bodySmall),
                if (sub != null) ...[
                  const SizedBox(width: 6),
                  Text(sub!, style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                ],
              ],
            ),
          ),
          Text(amount, style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: CalmTokens.fontDisplay, fontWeight: FontWeight.w600, color: tokens.clay,
          )),
        ],
      ),
    );
  }
}

class _PlanButton extends StatelessWidget {
  const _PlanButton({required this.label, required this.filled, required this.onTap});

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: filled ? tokens.sageDeep : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CalmTokens.radiusMd),
          side: filled ? BorderSide.none : BorderSide(color: theme.colorScheme.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: filled ? Colors.white : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

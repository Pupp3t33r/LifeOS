import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/calm_tokens.dart';
import '../../../../app/theme/category_colors.dart';
import '../../application/categories_providers.dart';
import '../../data/outbox/recurring_outbox.dart';
import '../../domain/category.dart';
import '../../domain/recurring/occurrence.dart';
import '../../domain/recurring/recurring_payment.dart';
import 'occurrence_actions.dart';
import 'recurring_shared.dart';
import 'sheet_container.dart';

/// The **Payment plan** resolve sheet (design/recurring · resolve): tapping a plan
/// installment's row body opens this detail. The amount defaults to the scheduled
/// payment but is **editable** — the honest "what did I actually pay" (ADR-0029) — and
/// it shows what's in the plan (its priceless contents) plus plan progress. Hosts the
/// actions a plan needs a home for: Mark paid, Skip, and Cancel plan (refund / no-refund).
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

class _PlanOccurrenceSheet extends ConsumerStatefulWidget {
  const _PlanOccurrenceSheet({
    required this.bottomSheet,
    required this.recurring,
    required this.occurrence,
  });

  final bool bottomSheet;
  final RecurringPayment recurring;
  final Occurrence occurrence;

  @override
  ConsumerState<_PlanOccurrenceSheet> createState() => _PlanOccurrenceSheetState();
}

class _PlanOccurrenceSheetState extends ConsumerState<_PlanOccurrenceSheet> {
  late final TextEditingController _amountCtrl;

  RecurringPayment get _recurring => widget.recurring;
  Occurrence get _occurrence => widget.occurrence;
  String get _currency => _occurrence.expectedAmount.currency;

  /// The scheduled amount as a positive magnitude — the field's default.
  double get _scheduledMagnitude => _occurrence.expectedAmount.amount.abs().toDouble();

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(text: _scheduledMagnitude.toStringAsFixed(2))
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  double? get _enteredMagnitude {
    final parsed = double.tryParse(_amountCtrl.text.trim());
    return parsed != null && parsed > 0 ? parsed : null;
  }

  /// This payment's position in the plan (1-based) and the plan's payment count,
  /// ordered as the server orders them (due date, then line id).
  (int, int) get _progress {
    final ordered = [..._recurring.scheduleLines]..sort((a, b) {
        final byDate = a.dueDate.compareTo(b.dueDate);
        return byDate != 0 ? byDate : a.lineId.compareTo(b.lineId);
      });
    final index = ordered.indexWhere((x) => x.lineId == _occurrence.occurrenceRef);
    return (index < 0 ? 1 : index + 1, ordered.length);
  }

  Future<void> _markPaid() async {
    final magnitude = _enteredMagnitude;
    if (magnitude == null) return;
    // Only send an amount adjustment when it differs from the scheduled amount; an
    // unchanged amount records the plan's scheduled reference line (ADR-0029).
    final changed = (magnitude - _scheduledMagnitude).abs() > 0.005;
    await markOccurrencePaidAsPlanned(
      ref,
      recurringId: _recurring.id,
      occurrence: _occurrence,
      description: _recurring.name,
      actualAmount: changed ? magnitude : null,
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _skip() async {
    await skipOccurrence(ref, recurringId: _recurring.id, occurrence: _occurrence);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _cancelPlan() async {
    final refunded = await _askRefund(context);
    if (refunded == null) return;
    await ref.read(recurringOutboxProvider).cancel(recurringId: _recurring.id, refunded: refunded);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final nameById = {for (final c in categories) c.id: c.name};
    final (k, n) = _progress;
    final items = _recurring.items;

    return SheetContainer(
      bottomSheet: widget.bottomSheet,
      title: '▤ ${_recurring.name}',
      icon: null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Payment $k of $n · Payment plan',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: 12),

          // Editable amount — defaults to the scheduled payment, adjust to what was paid.
          _AmountField(
            controller: _amountCtrl,
            isIncome: _recurring.isIncome,
            currency: _currency,
          ),
          const SizedBox(height: 16),

          if (items.isNotEmpty) ...[
            Text("WHAT'S IN THE PLAN",
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
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: theme.colorScheme.outline),
                    _ContentRow(
                      label: items[i].description ??
                          nameById[items[i].categoryId] ??
                          'Item',
                      sub: nameById[items[i].categoryId],
                      note: items[i].referenceValue == null
                          ? null
                          : 'MSRP ${formatMagnitude(items[i].referenceValue!.amount, _currency)}',
                      categoryId: items[i].categoryId,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
          ] else
            const SizedBox(height: 4),

          _PlanButton(
            label: 'Mark paid',
            filled: true,
            onTap: _enteredMagnitude == null ? null : _markPaid,
          ),
          const SizedBox(height: 8),
          _PlanButton(label: 'Skip this one', filled: false, onTap: _skip),
          const SizedBox(height: 2),
          Center(
            child: TextButton(
              onPressed: _cancelPlan,
              child: Text('Cancel plan · refund or no refund',
                  style: theme.textTheme.bodySmall?.copyWith(color: tokens.clay, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

/// The editable "what was actually paid" field — a bordered amount box seeded with the
/// scheduled payment (ADR-0029).
class _AmountField extends StatelessWidget {
  const _AmountField({required this.controller, required this.isIncome, required this.currency});

  final TextEditingController controller;
  final bool isIncome;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(CalmTokens.radiusMd),
      ),
      child: Row(
        children: [
          Text(isIncome ? '+' : '−',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontFamily: CalmTokens.fontDisplay,
                fontWeight: FontWeight.w700,
                color: isIncome ? tokens.sageDeep : theme.colorScheme.onSurface,
              )),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              style: theme.textTheme.headlineSmall?.copyWith(
                fontFamily: CalmTokens.fontDisplay,
                fontWeight: FontWeight.w700,
                color: isIncome ? tokens.sageDeep : theme.colorScheme.onSurface,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: '0.00',
              ),
            ),
          ),
          Text(currency,
              style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
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

class _ContentRow extends StatelessWidget {
  const _ContentRow({required this.label, this.sub, this.note, this.categoryId});

  final String label;
  final String? sub;
  final String? note;
  final String? categoryId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: categoryId != null ? CategoryColors.slotFor(categoryId!).of(context) : tokens.line,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Flexible(child: Text(label, style: theme.textTheme.bodySmall)),
                if (sub != null) ...[
                  const SizedBox(width: 6),
                  Text(sub!, style: theme.textTheme.labelSmall?.copyWith(color: muted)),
                ],
              ],
            ),
          ),
          if (note != null)
            Text(note!, style: theme.textTheme.labelSmall?.copyWith(color: muted)),
        ],
      ),
    );
  }
}

class _PlanButton extends StatelessWidget {
  const _PlanButton({required this.label, required this.filled, required this.onTap});

  final String label;
  final bool filled;
  final VoidCallback? onTap;

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

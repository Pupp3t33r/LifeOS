import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/calm_tokens.dart';
import '../../data/outbox/recurring_outbox.dart';
import '../../domain/recurring/occurrence.dart';
import '../../domain/recurring/recurring_line.dart';
import '../../domain/recurring/recurring_payment.dart';
import 'create_widgets.dart';
import 'occurrence_actions.dart';
import 'recurring_shared.dart';
import 'sheet_container.dart';

/// The **Ongoing** resolve sheet (design/recurring · resolve): tap an Ongoing row's
/// body to log a *different* real amount. The amount seeds from the plan and can be
/// overwritten; confirming records the real figure as a flow, leaving the plan
/// untouched. Also hosts Skip. (A Payment-plan payment has no override — see
/// [showPlanOccurrence].)
Future<void> showResolveOngoing(
  BuildContext context,
  RecurringPayment recurring,
  Occurrence occurrence,
) =>
    showMoneySheet(
      context,
      (bottomSheet) => _ResolveOngoingSheet(
        bottomSheet: bottomSheet,
        recurring: recurring,
        occurrence: occurrence,
      ),
    );

class _ResolveOngoingSheet extends ConsumerStatefulWidget {
  const _ResolveOngoingSheet({
    required this.bottomSheet,
    required this.recurring,
    required this.occurrence,
  });

  final bool bottomSheet;
  final RecurringPayment recurring;
  final Occurrence occurrence;

  @override
  ConsumerState<_ResolveOngoingSheet> createState() => _ResolveOngoingSheetState();
}

class _ResolveOngoingSheetState extends ConsumerState<_ResolveOngoingSheet> {
  late final TextEditingController _amountCtrl;
  late DateTime _date;
  bool _submitting = false;

  Occurrence get _occ => widget.occurrence;
  String get _currency => _occ.expectedAmount.currency;
  double get _expectedMagnitude => _occ.expectedAmount.amount.abs().toDouble();
  String? get _categoryId =>
      _occ.lines.map((x) => x.categoryId).firstWhere((x) => x != null, orElse: () => null);

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(text: _expectedMagnitude.toStringAsFixed(2));
    _amountCtrl.addListener(() => setState(() {}));
    _date = _occ.dueDate;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  double? get _amount {
    final v = double.tryParse(_amountCtrl.text.trim());
    return (v != null && v > 0) ? v : null;
  }

  Future<void> _markPaid() async {
    final amount = _amount;
    if (amount == null) return;
    setState(() => _submitting = true);
    await ref.read(recurringOutboxProvider).confirm(
          recurringId: widget.recurring.id,
          occurrenceRef: _occ.occurrenceRef,
          entryId: recurringUuidV4(),
          occurredAt: _date,
          lines: [RecurringLineDraft(amount: amount, categoryId: _categoryId)],
          description: widget.recurring.name,
        );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _skip() async {
    await skipOccurrence(ref, recurringId: widget.recurring.id, occurrence: _occ);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    final amount = _amount;

    return SheetContainer(
      bottomSheet: widget.bottomSheet,
      title: '⌁ ${widget.recurring.name}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: tokens.sage.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(CalmTokens.radiusSm),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Row(
              children: [
                Text('Planned', style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                const Spacer(),
                Text(
                  formatSigned(_occ.expectedAmount.amount, _currency),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontFamily: CalmTokens.fontDisplay, fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text('Amount paid', style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontWeight: FontWeight.w600, letterSpacing: 0.6,
          )),
          const SizedBox(height: 6),
          MoneyAmountField(
            controller: _amountCtrl,
            isIncome: widget.recurring.isIncome,
            currency: _currency,
            onCurrencyTap: () {}, // currency is fixed to the recurring's
          ),
          const SizedBox(height: 12),
          PickerButton(
            label: 'Paid on',
            value: _dateLabel(_date),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(_date.year - 1),
                lastDate: DateTime(_date.year + 2),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          const SizedBox(height: 18),
          PrimarySaveButton(
            label: 'Mark paid',
            trailing: amount != null
                ? formatSigned(widget.recurring.isIncome ? amount : -amount, _currency)
                : null,
            enabled: amount != null && !_submitting,
            loading: _submitting,
            onTap: _markPaid,
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _submitting ? null : _skip,
              child: Text.rich(TextSpan(
                text: "Didn't happen?  ",
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                children: [
                  TextSpan(
                    text: 'Skip',
                    style: TextStyle(color: tokens.clay, fontWeight: FontWeight.w600),
                  ),
                ],
              )),
            ),
          ),
        ],
      ),
    );
  }
}

String _dateLabel(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

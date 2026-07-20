import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/calm_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/outbox/planned_purchase_outbox.dart';
import '../../data/outbox/recurring_outbox.dart' show recurringUuidV4;
import '../../domain/planned_purchase.dart';
import 'create_widgets.dart';
import 'recurring_shared.dart';
import 'sheet_container.dart';

/// Shared planned-purchase mutations (ADR-0018) — thin wrappers over
/// [PlannedPurchaseOutbox] so the worklist and its sheets queue the same idempotent
/// ops. Pay and cancel both target the planned purchase's own period ([year]/[month]).

/// Buy a planned purchase — records a settling flow. Omit [amount] to pay the planned
/// total; pass it to record a different actual (collapsed to one line, ADR-0018).
Future<void> buyPlannedPurchase(
  WidgetRef ref, {
  required PlannedPurchase planned,
  required int year,
  required int month,
  double? amount,
}) {
  return ref.read(plannedPurchaseOutboxProvider).pay(
        plannedEntryId: planned.entryId,
        flowEntryId: recurringUuidV4(),
        year: year,
        month: month,
        occurredAt: DateTime.now(),
        amount: amount,
        description: planned.description,
      );
}

/// Remove a planned purchase from the plan (cancel, terminal).
Future<void> removePlannedPurchase(
  WidgetRef ref, {
  required String entryId,
  required int year,
  required int month,
}) {
  return ref.read(plannedPurchaseOutboxProvider).cancel(
        entryId: entryId,
        year: year,
        month: month,
      );
}

/// The planned-purchase detail actions: mark it bought (only [canBuy] — an actual
/// can't be filed into a future/Planning period, ADR-0023), or remove it from the plan.
Future<void> showPlannedActions(
  BuildContext context,
  WidgetRef ref,
  PlannedPurchase planned,
  int year,
  int month, {
  required bool canBuy,
}) {
  return showMoneySheet(context, (bottomSheet) {
    return _PlannedActionsSheet(
      bottomSheet: bottomSheet, planned: planned, year: year, month: month, canBuy: canBuy);
  });
}

/// Buy a planned purchase, confirming (or adjusting) what was actually paid.
Future<void> showBuyPlanned(
  BuildContext context,
  WidgetRef ref,
  PlannedPurchase planned,
  int year,
  int month,
) {
  return showMoneySheet(context, (bottomSheet) {
    return _BuyPlannedSheet(
      bottomSheet: bottomSheet, planned: planned, year: year, month: month);
  });
}

class _PlannedActionsSheet extends ConsumerWidget {
  const _PlannedActionsSheet({
    required this.bottomSheet,
    required this.planned,
    required this.year,
    required this.month,
    required this.canBuy,
  });

  final bool bottomSheet;
  final PlannedPurchase planned;
  final int year;
  final int month;
  final bool canBuy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final l10n = AppLocalizations.of(context);

    return SheetContainer(
      bottomSheet: bottomSheet,
      title: l10n.createPlannedSheetTitle,
      icon: Icons.shopping_bag_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            planned.description ?? l10n.createPlannedSheetTitle,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            formatSigned(planned.total.amount, planned.total.currency),
            style: theme.textTheme.titleLarge?.copyWith(
              fontFamily: CalmTokens.fontDisplay,
              fontWeight: FontWeight.w700,
              color: tokens.clay,
            ),
          ),
          const SizedBox(height: 20),
          if (canBuy) ...[
            PrimarySaveButton(
              label: l10n.plannedActionMarkBought,
              enabled: true,
              onTap: () async {
                Navigator.of(context).pop();
                await showBuyPlanned(context, ref, planned, year, month);
              },
            ),
            const SizedBox(height: 10),
          ],
          TextButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              await removePlannedPurchase(ref, entryId: planned.entryId, year: year, month: month);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.plannedActionRemoved)),
                );
              }
            },
            icon: Icon(Icons.delete_outline, size: 18, color: muted),
            label: Text(l10n.plannedActionRemoveFromPlan, style: TextStyle(color: muted)),
          ),
        ],
      ),
    );
  }
}

class _BuyPlannedSheet extends ConsumerStatefulWidget {
  const _BuyPlannedSheet({
    required this.bottomSheet,
    required this.planned,
    required this.year,
    required this.month,
  });

  final bool bottomSheet;
  final PlannedPurchase planned;
  final int year;
  final int month;

  @override
  ConsumerState<_BuyPlannedSheet> createState() => _BuyPlannedSheetState();
}

class _BuyPlannedSheetState extends ConsumerState<_BuyPlannedSheet> {
  late final TextEditingController _amountCtrl;
  bool _submitting = false;

  /// The planned magnitude (unsigned) — the default "what was paid".
  double get _plannedMagnitude => widget.planned.total.amount.abs().toDouble();

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(text: _plannedMagnitude.toStringAsFixed(2));
    _amountCtrl.addListener(() => setState(() {}));
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

  Future<void> _confirm() async {
    final amount = _amount;
    if (amount == null) return;
    setState(() => _submitting = true);

    // Pass the amount only when it differs from the plan — otherwise record the planned
    // lines as-is (preserving categories), matching the server's amount-only override.
    final adjusted = (amount - _plannedMagnitude).abs() < 0.005 ? null : amount;
    await buyPlannedPurchase(
      ref,
      planned: widget.planned,
      year: widget.year,
      month: widget.month,
      amount: adjusted,
    );

    if (!mounted) return;
    Navigator.of(context).pop();
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.plannedActionMarkedBought)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final currency = widget.planned.total.currency;
    final l10n = AppLocalizations.of(context);

    return SheetContainer(
      bottomSheet: widget.bottomSheet,
      title: l10n.plannedActionMarkBought,
      icon: Icons.shopping_bag_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.planned.description ?? l10n.createPlannedSheetTitle,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.plannedActionBuyDescription,
            style: theme.textTheme.bodySmall?.copyWith(color: muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          MoneyAmountField(
            controller: _amountCtrl,
            isIncome: false,
            currency: currency,
            onCurrencyTap: () {}, // currency is fixed to the planned purchase's
          ),
          const SizedBox(height: 20),
          PrimarySaveButton(
            label: l10n.plannedActionMarkBought,
            enabled: _amount != null && !_submitting,
            loading: _submitting,
            onTap: _confirm,
          ),
        ],
      ),
    );
  }
}

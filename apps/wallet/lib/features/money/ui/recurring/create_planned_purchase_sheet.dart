import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/category_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/categories_providers.dart';
import '../../application/preferences_providers.dart';
import '../../data/outbox/planned_purchase_outbox.dart';
import '../../data/outbox/record_flow.dart';
import '../../data/outbox/recurring_outbox.dart' show recurringUuidV4;
import '../../domain/category.dart';
import 'create_widgets.dart';
import 'recurring_shared.dart';
import 'sheet_container.dart';

/// Opens the **Planned purchase** create sheet — "I intend to buy X this month"
/// (ADR-0018). Always spending: an amount + name + category, filed onto the viewed
/// period ([year]/[month]) through the outbox. No date — a planned purchase belongs
/// to its period, not a day.
Future<void> showCreatePlannedPurchase(
  BuildContext context, {
  required int year,
  required int month,
}) =>
    showMoneySheet(
      context,
      (bottomSheet) =>
          CreatePlannedPurchaseSheet(bottomSheet: bottomSheet, year: year, month: month),
    );

class CreatePlannedPurchaseSheet extends ConsumerStatefulWidget {
  const CreatePlannedPurchaseSheet({
    super.key,
    required this.bottomSheet,
    required this.year,
    required this.month,
  });

  final bool bottomSheet;
  final int year;
  final int month;

  @override
  ConsumerState<CreatePlannedPurchaseSheet> createState() =>
      _CreatePlannedPurchaseSheetState();
}

class _CreatePlannedPurchaseSheetState extends ConsumerState<CreatePlannedPurchaseSheet> {
  String? _currency;
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController();
  String? _categoryId;
  String? _categoryName;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(() => setState(() {}));
    _amountCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  String _effectiveCurrency() =>
      _currency ?? ref.read(preferencesProvider).value?.displayCurrency ?? 'USD';

  double? get _amount {
    final v = double.tryParse(_amountCtrl.text.trim());
    return (v != null && v > 0) ? v : null;
  }

  bool get _canSave =>
      _nameCtrl.text.trim().isNotEmpty && _amount != null && !_submitting;

  Future<void> _save() async {
    final amount = _amount;
    if (amount == null) return;
    setState(() => _submitting = true);

    await ref.read(plannedPurchaseOutboxProvider).add(
          entryId: recurringUuidV4(),
          year: widget.year,
          month: widget.month,
          currency: _effectiveCurrency(),
          description: _nameCtrl.text.trim(),
          lines: [FlowLineDraft(amount: amount, categoryId: _categoryId)],
        );

    if (!mounted) return;
    Navigator.of(context).pop();
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.createPlannedAdded)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final currency = _effectiveCurrency();
    final l10n = AppLocalizations.of(context);

    return SheetContainer(
      bottomSheet: widget.bottomSheet,
      title: l10n.createPlannedSheetTitle,
      icon: Icons.shopping_bag_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.createPlannedDescription(formatMonthYear(context, widget.year, widget.month, long: true)),
            style: theme.textTheme.bodySmall?.copyWith(color: muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          MoneyAmountField(
            controller: _amountCtrl,
            isIncome: false,
            currency: currency,
            onCurrencyTap: () async {
              final picked = await pickCurrency(context, selected: currency);
              if (picked != null) setState(() => _currency = picked);
            },
          ),
          const SizedBox(height: 12),
          SheetTextField(controller: _nameCtrl, hint: l10n.createPlannedNameHint),
          const SizedBox(height: 12),
          PickerButton(
            label: l10n.createCategoryLabel,
            value: _categoryName ?? l10n.createCategoryLabel,
            muted: _categoryName == null,
            dotColor: _categoryId != null
                ? CategoryColors.slotFor(_categoryId!).of(context)
                : null,
            onTap: () async {
              final picked = await pickCategory(context, categories, selectedId: _categoryId);
              if (picked == null) return;
              setState(() {
                if (identical(picked, kNoCategory)) {
                  _categoryId = null;
                  _categoryName = null;
                } else {
                  _categoryId = picked.id;
                  _categoryName = picked.name;
                }
              });
            },
          ),
          const SizedBox(height: 20),
          PrimarySaveButton(
            label: l10n.createPlannedAddButton,
            enabled: _canSave,
            loading: _submitting,
            onTap: _save,
          ),
        ],
      ),
    );
  }
}

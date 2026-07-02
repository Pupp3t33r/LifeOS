import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/category_colors.dart';
import '../../application/categories_providers.dart';
import '../../application/preferences_providers.dart';
import '../../data/outbox/recurring_outbox.dart';
import '../../domain/category.dart';
import '../../domain/recurring/recurrence_rule.dart';
import '../../domain/recurring/recurring_line.dart';
import 'create_widgets.dart';
import 'recurring_shared.dart';
import 'rule_editor.dart';
import 'sheet_container.dart';

/// Opens the **Ongoing** (Live) create sheet — money that keeps coming until you stop
/// it: an amount + name + category and a Repeats rule, queued through the outbox.
Future<void> showCreateOngoing(BuildContext context) =>
    showMoneySheet(context, (bottomSheet) => CreateOngoingSheet(bottomSheet: bottomSheet));

class CreateOngoingSheet extends ConsumerStatefulWidget {
  const CreateOngoingSheet({super.key, required this.bottomSheet});

  final bool bottomSheet;

  @override
  ConsumerState<CreateOngoingSheet> createState() => _CreateOngoingSheetState();
}

class _CreateOngoingSheetState extends ConsumerState<CreateOngoingSheet> {
  bool _isIncome = false;
  String? _currency;
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController();
  String? _categoryId;
  String? _categoryName;
  RecurrenceRule? _rule;
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
      _nameCtrl.text.trim().isNotEmpty && _amount != null && _rule != null && !_submitting;

  Future<void> _save() async {
    final amount = _amount;
    final rule = _rule;
    if (amount == null || rule == null) return;
    setState(() => _submitting = true);

    await ref.read(recurringOutboxProvider).createOngoing(
          recurringId: recurringUuidV4(),
          name: _nameCtrl.text.trim(),
          isIncome: _isIncome,
          currency: _effectiveCurrency(),
          categoryId: _categoryId,
          rule: rule,
          estimateLines: [
            RecurringLineDraft(amount: amount, categoryId: _categoryId),
          ],
        );

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ongoing added')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final currency = _effectiveCurrency();

    return SheetContainer(
      bottomSheet: widget.bottomSheet,
      title: '↻ Ongoing',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DirectionToggle(isIncome: _isIncome, onChanged: (v) => setState(() => _isIncome = v)),
          const SizedBox(height: 16),
          MoneyAmountField(
            controller: _amountCtrl,
            isIncome: _isIncome,
            currency: currency,
            onCurrencyTap: () async {
              final picked = await pickCurrency(context, selected: currency);
              if (picked != null) setState(() => _currency = picked);
            },
          ),
          const SizedBox(height: 12),
          SheetTextField(controller: _nameCtrl, hint: 'What is it?  e.g. Rent'),
          const SizedBox(height: 12),
          PickerButton(
            label: 'Category',
            value: _categoryName ?? 'Category',
            muted: _categoryName == null,
            dotColor: _categoryId != null ? CategoryPalette.forId(_categoryId!).of(context) : null,
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
          const SizedBox(height: 16),
          RuleEditor(onChanged: (rule) => setState(() => _rule = rule)),
          const SizedBox(height: 20),
          PrimarySaveButton(label: 'Save', enabled: _canSave, loading: _submitting, onTap: _save),
        ],
      ),
    );
  }
}

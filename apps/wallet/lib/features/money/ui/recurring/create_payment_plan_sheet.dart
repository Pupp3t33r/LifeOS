import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/calm_tokens.dart';
import '../../../../app/theme/category_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/categories_providers.dart';
import '../../application/preferences_providers.dart';
import '../../data/outbox/recurring_outbox.dart';
import '../../domain/category.dart';
import '../../domain/recurring/plan_item.dart';
import '../../domain/recurring/schedule_line.dart';
import 'create_widgets.dart';
import 'recurring_shared.dart';
import 'sheet_container.dart';

/// Opens the **Payment plan** (Materialized) create sheet — one financed purchase: a
/// priceless item list (what you bought, real categories, optional MSRP) plus bare
/// `{date, amount}` payments. The plan total is simply the sum of the payments; items
/// carry no cost and needn't balance anything (ADR-0029). Queued via the outbox.
Future<void> showCreatePaymentPlan(BuildContext context) =>
    showMoneySheet(context, (bottomSheet) => CreatePaymentPlanSheet(bottomSheet: bottomSheet));

class _ItemDraft {
  _ItemDraft({this.referenceValue, this.categoryId, this.categoryName, this.description});
  double? referenceValue;
  String? categoryId;
  String? categoryName;
  String? description;
}

class _PaymentDraft {
  _PaymentDraft({required this.lineId, required this.dueDate, required this.amount});
  final String lineId;
  DateTime dueDate;
  double amount;
}

class CreatePaymentPlanSheet extends ConsumerStatefulWidget {
  const CreatePaymentPlanSheet({super.key, required this.bottomSheet});

  final bool bottomSheet;

  @override
  ConsumerState<CreatePaymentPlanSheet> createState() => _CreatePaymentPlanSheetState();
}

class _CreatePaymentPlanSheetState extends ConsumerState<CreatePaymentPlanSheet> {
  bool _isIncome = false;
  String? _currency;
  final TextEditingController _nameCtrl = TextEditingController();
  final List<_ItemDraft> _items = [];
  final List<_PaymentDraft> _payments = [];
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  String _effectiveCurrency() =>
      _currency ?? ref.read(preferencesProvider).value?.displayCurrency ?? 'USD';

  double get _paymentsTotal => _payments.fold(0, (sum, x) => sum + x.amount);

  bool get _canSave =>
      _nameCtrl.text.trim().isNotEmpty &&
      _items.isNotEmpty &&
      _payments.isNotEmpty &&
      !_submitting;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _submitting = true);

    await ref.read(recurringOutboxProvider).createPaymentPlan(
          recurringId: recurringUuidV4(),
          name: _nameCtrl.text.trim(),
          isIncome: _isIncome,
          currency: _effectiveCurrency(),
          items: [
            for (final item in _items)
              PlanItemDraft(
                description: item.description,
                referenceValue: item.referenceValue,
                categoryId: item.categoryId,
              ),
          ],
          scheduleLines: [
            for (final payment in _payments)
              ScheduleLineDraft(
                lineId: payment.lineId, dueDate: payment.dueDate, amount: payment.amount),
          ],
        );

    if (!mounted) return;
    Navigator.of(context).pop();
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.createPlanAdded)),
    );
  }

  Future<void> _addItem() async {
    final categories = ref.read(categoriesProvider).value ?? const <Category>[];
    final draft = await _showItemComposer(context, _effectiveCurrency(), _isIncome, categories);
    if (draft != null) setState(() => _items.add(draft));
  }

  Future<void> _addPayment() async {
    final lastDate = _payments.isEmpty
        ? DateTime.now()
        : DateTime(_payments.last.dueDate.year, _payments.last.dueDate.month + 1, _payments.last.dueDate.day);
    final seed = _payments.isEmpty ? 0.0 : _payments.last.amount;
    final draft = await _showPaymentComposer(context, _effectiveCurrency(), _isIncome, lastDate, seed);
    if (draft != null) setState(() => _payments.add(draft));
  }

  @override
  Widget build(BuildContext context) {
    final currency = _effectiveCurrency();
    final l10n = AppLocalizations.of(context);

    return SheetContainer(
      bottomSheet: widget.bottomSheet,
      title: l10n.createPlanSheetTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DirectionToggle(isIncome: _isIncome, onChanged: (v) => setState(() => _isIncome = v)),
          const SizedBox(height: 16),
          SheetTextField(controller: _nameCtrl, hint: l10n.createPlanNameHint),
          const SizedBox(height: 12),
          PickerButton(
            label: l10n.createCurrencyLabel,
            value: currency,
            onTap: () async {
              final picked = await pickCurrency(context, selected: currency);
              if (picked != null && mounted) setState(() => _currency = picked);
            },
          ),
          const SizedBox(height: 18),

          _SectionHeader(
            title: l10n.createPlanItemsTitle,
            subtitle: l10n.createPlanItemsSubtitle,
            trailing: _items.isEmpty ? null : '${_items.length}',
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _items.length; i++)
            _ItemRow(
              item: _items[i],
              currency: currency,
              onDelete: () => setState(() => _items.removeAt(i)),
            ),
          _AddRow(label: l10n.createPlanAddItem, accent: false, onTap: _addItem),
          const SizedBox(height: 18),

          _SectionHeader(
            title: l10n.createPlanPaymentsTitle,
            subtitle: l10n.createPlanPaymentsSubtitle,
            trailing: formatSigned(_isIncome ? _paymentsTotal : -_paymentsTotal, currency),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _payments.length; i++)
            _PaymentRow(
              index: i + 1,
              payment: _payments[i],
              isIncome: _isIncome,
              currency: currency,
              onDelete: () => setState(() => _payments.removeAt(i)),
            ),
          _AddRow(label: l10n.createPlanAddPayment, accent: true, onTap: _addPayment),
          const SizedBox(height: 16),

          _PlanTotalBanner(
            total: _isIncome ? _paymentsTotal : -_paymentsTotal,
            count: _payments.length,
            currency: currency,
          ),
          const SizedBox(height: 16),
          PrimarySaveButton(label: l10n.createSaveButton, enabled: _canSave, loading: _submitting, onTap: _save),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle, this.trailing});

  final String title;
  final String subtitle;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    return Row(
      children: [
        Text(title, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Expanded(child: Text(subtitle, style: theme.textTheme.labelSmall?.copyWith(color: muted))),
        if (trailing != null)
          Text(
            trailing!,
            style: theme.textTheme.titleSmall?.copyWith(
              fontFamily: CalmTokens.fontDisplay, fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.currency, required this.onDelete});

  final _ItemDraft item;
  final String currency;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 9, height: 9,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: item.categoryId != null
                  ? CategoryColors.slotFor(item.categoryId!).of(context)
                  : tokens.line,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.description ?? l10n.createPlanItemFallback,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                if (item.categoryName != null)
                  Text(item.categoryName!,
                      style: theme.textTheme.labelSmall?.copyWith(color: muted)),
              ],
            ),
          ),
          // The optional reference value (MSRP) reads as a muted annotation, never a cost.
          if (item.referenceValue != null)
            Text(
              l10n.createPlanItemMsrpAnnotation(formatMagnitude(item.referenceValue!, currency)),
              style: theme.textTheme.labelSmall?.copyWith(color: muted),
            ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            visualDensity: VisualDensity.compact,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.index,
    required this.payment,
    required this.isIncome,
    required this.currency,
    required this.onDelete,
  });

  final int index;
  final _PaymentDraft payment;
  final bool isIncome;
  final String currency;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    final magnitude = isIncome ? payment.amount : -payment.amount;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 22, height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tokens.sage.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Text('$index',
                style: theme.textTheme.labelSmall?.copyWith(color: tokens.sageDeep, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(formatFullDate(context, payment.dueDate), style: theme.textTheme.bodyMedium),
          ),
          Text(
            formatSigned(magnitude, currency),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: CalmTokens.fontDisplay,
              fontWeight: FontWeight.w600,
              color: isIncome ? tokens.sageDeep : tokens.clay,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            visualDensity: VisualDensity.compact,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _AddRow extends StatelessWidget {
  const _AddRow({required this.label, required this.accent, required this.onTap});

  final String label;
  final bool accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    final color = accent ? tokens.sageDeep : tokens.clay;
    return InkWell(
      borderRadius: BorderRadius.circular(CalmTokens.radiusSm),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(Icons.add_circle_outline, size: 18, color: color),
            const SizedBox(width: 8),
            Text(label, style: theme.textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// The plan total — simply the sum of the payments (ADR-0029). Replaces the old
/// items↔payments balance banner; there is nothing to reconcile.
class _PlanTotalBanner extends StatelessWidget {
  const _PlanTotalBanner({required this.total, required this.count, required this.currency});

  final double total;
  final int count;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    final l10n = AppLocalizations.of(context);
    final label = count == 0
        ? l10n.createPlanTotalEmpty
        : l10n.createPlanTotalCount(count);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.sage.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(CalmTokens.radiusSm),
        border: Border.all(color: tokens.sage.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface)),
          ),
          if (count > 0)
            Text(
              formatSigned(total, currency),
              style: theme.textTheme.titleSmall?.copyWith(
                fontFamily: CalmTokens.fontDisplay, fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

// ---- add-item / add-payment composers ----

Future<_ItemDraft?> _showItemComposer(
  BuildContext context,
  String currency,
  bool isIncome,
  List<Category> categories,
) {
  final refCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  String? categoryId;
  String? categoryName;

  return showModalBottomSheet<_ItemDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheet) {
        final name = descCtrl.text.trim();
        final reference = double.tryParse(refCtrl.text.trim());
        final valid = name.isNotEmpty;
        final l10n = AppLocalizations.of(context);
        return SheetContainer(
          bottomSheet: true,
          title: l10n.createPlanComposerItemTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetTextField(
                controller: descCtrl,
                hint: l10n.createPlanComposerItemHint,
                onChanged: () => setSheet(() {}),
              ),
              const SizedBox(height: 12),
              // Priceless — the only number is an optional reference (MSRP), never a cost.
              _ComposerAmount(
                controller: refCtrl,
                label: l10n.createPlanComposerMsrpLabel,
                hint: l10n.createPlanComposerMsrpHint,
                suffix: currency,
                onChanged: () => setSheet(() {}),
              ),
              const SizedBox(height: 12),
              PickerButton(
                label: l10n.createCategoryLabel,
                value: categoryName ?? l10n.createCategoryLabel,
                muted: categoryName == null,
                dotColor: categoryId != null ? CategoryColors.slotFor(categoryId!).of(context) : null,
                onTap: () async {
                  final picked = await pickCategory(context, categories, selectedId: categoryId);
                  if (picked == null) return;
                  setSheet(() {
                    if (identical(picked, kNoCategory)) {
                      categoryId = null;
                      categoryName = null;
                    } else {
                      categoryId = picked.id;
                      categoryName = picked.name;
                    }
                  });
                },
              ),
              const SizedBox(height: 18),
              PrimarySaveButton(
                label: l10n.createPlanAddItem,
                enabled: valid,
                onTap: () => Navigator.of(context).pop(_ItemDraft(
                  referenceValue: reference != null && reference > 0 ? reference : null,
                  categoryId: categoryId,
                  categoryName: categoryName,
                  description: name.isEmpty ? null : name,
                )),
              ),
            ],
          ),
        );
      },
    ),
  );
}

Future<_PaymentDraft?> _showPaymentComposer(
  BuildContext context,
  String currency,
  bool isIncome,
  DateTime initialDate,
  double initialAmount,
) {
  final amountCtrl = TextEditingController(text: initialAmount > 0 ? initialAmount.toStringAsFixed(2) : '');
  var date = initialDate;

  return showModalBottomSheet<_PaymentDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheet) {
        final amount = double.tryParse(amountCtrl.text.trim());
        final valid = amount != null && amount > 0;
        final l10n = AppLocalizations.of(context);
        return SheetContainer(
          bottomSheet: true,
          title: l10n.createPlanComposerPaymentTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PickerButton(
                label: l10n.createPlanComposerDateLabel,
                value: formatFullDate(context, date),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(DateTime.now().year - 1),
                    lastDate: DateTime(DateTime.now().year + 20),
                  );
                  if (picked != null) setSheet(() => date = picked);
                },
              ),
              const SizedBox(height: 12),
              _ComposerAmount(
                controller: amountCtrl,
                suffix: currency,
                label: l10n.createPlanComposerAmountLabel,
                onChanged: () => setSheet(() {})),
              const SizedBox(height: 18),
              PrimarySaveButton(
                label: l10n.createPlanAddPayment,
                enabled: valid,
                onTap: () => Navigator.of(context).pop(_PaymentDraft(
                  lineId: recurringUuidV4(),
                  dueDate: date,
                  amount: amount!,
                )),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// A numeric field for the composers with a persistent caption. [label] always shows
/// ("Amount" for a payment, "MSRP" for an item's optional reference) so the field reads
/// as what it is even when empty; [suffix] shows the currency unit.
class _ComposerAmount extends StatelessWidget {
  const _ComposerAmount({
    required this.controller,
    required this.onChanged,
    this.label = 'Amount',
    this.hint = '0.00',
    this.suffix,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;
  final String label;
  final String hint;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      onChanged: (_) => onChanged(),
      style: theme.textTheme.titleMedium?.copyWith(
        fontFamily: CalmTokens.fontDisplay, fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintText: hint,
        suffixText: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(CalmTokens.radiusSm)),
      ),
    );
  }
}

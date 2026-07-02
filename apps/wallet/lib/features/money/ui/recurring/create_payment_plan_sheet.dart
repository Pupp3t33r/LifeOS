import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/calm_tokens.dart';
import '../../../../app/theme/category_colors.dart';
import '../../application/categories_providers.dart';
import '../../application/preferences_providers.dart';
import '../../data/outbox/recurring_outbox.dart';
import '../../domain/category.dart';
import '../../domain/recurring/recurring_line.dart';
import '../../domain/recurring/schedule_line.dart';
import 'create_widgets.dart';
import 'recurring_shared.dart';
import 'sheet_container.dart';

/// Opens the **Payment plan** (Materialized) create sheet — one financed purchase: an
/// item list (what you bought, real categories) plus bare `{date, amount}` payments,
/// with the one rule that payments must sum to items (ADR-0028). Queued via the outbox.
Future<void> showCreatePaymentPlan(BuildContext context) =>
    showMoneySheet(context, (bottomSheet) => CreatePaymentPlanSheet(bottomSheet: bottomSheet));

class _ItemDraft {
  _ItemDraft({required this.amount, this.categoryId, this.categoryName, this.description});
  double amount;
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

  double get _itemsTotal => _items.fold(0, (sum, x) => sum + x.amount);
  double get _paymentsTotal => _payments.fold(0, (sum, x) => sum + x.amount);
  int get _remainingCents => (_itemsTotal * 100).round() - (_paymentsTotal * 100).round();
  bool get _balanced => _remainingCents == 0 && _items.isNotEmpty && _payments.isNotEmpty;

  bool get _canSave =>
      _nameCtrl.text.trim().isNotEmpty && _balanced && !_submitting;

  Future<void> _save() async {
    if (!_balanced) return;
    setState(() => _submitting = true);

    await ref.read(recurringOutboxProvider).createPaymentPlan(
          recurringId: recurringUuidV4(),
          name: _nameCtrl.text.trim(),
          isIncome: _isIncome,
          currency: _effectiveCurrency(),
          items: [
            for (final item in _items)
              RecurringLineDraft(
                amount: item.amount, categoryId: item.categoryId, description: item.description),
          ],
          scheduleLines: [
            for (final payment in _payments)
              ScheduleLineDraft(
                lineId: payment.lineId, dueDate: payment.dueDate, amount: payment.amount),
          ],
        );

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment plan added')),
    );
  }

  Future<void> _addItem() async {
    final categories = ref.read(categoriesProvider).value ?? const <Category>[];
    final draft = await _showItemComposer(context, categories);
    if (draft != null) setState(() => _items.add(draft));
  }

  Future<void> _addPayment() async {
    final lastDate = _payments.isEmpty
        ? DateTime.now()
        : DateTime(_payments.last.dueDate.year, _payments.last.dueDate.month + 1, _payments.last.dueDate.day);
    final remaining = _remainingCents > 0 ? _remainingCents / 100 : (_payments.isEmpty ? 0.0 : _payments.last.amount);
    final draft = await _showPaymentComposer(context, _effectiveCurrency(), _isIncome, lastDate, remaining);
    if (draft != null) setState(() => _payments.add(draft));
  }

  @override
  Widget build(BuildContext context) {
    final currency = _effectiveCurrency();

    return SheetContainer(
      bottomSheet: widget.bottomSheet,
      title: '▤ Payment plan',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DirectionToggle(isIncome: _isIncome, onChanged: (v) => setState(() => _isIncome = v)),
          const SizedBox(height: 16),
          SheetTextField(controller: _nameCtrl, hint: 'What is it?  e.g. Gloomhaven pledge'),
          const SizedBox(height: 18),

          _SectionHeader(
            title: 'Items',
            subtitle: 'what you bought',
            total: formatSigned(_isIncome ? _itemsTotal : -_itemsTotal, currency),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _items.length; i++)
            _ItemRow(
              item: _items[i],
              isIncome: _isIncome,
              currency: currency,
              onDelete: () => setState(() => _items.removeAt(i)),
            ),
          _AddRow(label: 'Add item', accent: false, onTap: _addItem),
          const SizedBox(height: 18),

          _SectionHeader(
            title: 'Payments',
            subtitle: 'how you pay it',
            total: formatSigned(_isIncome ? _paymentsTotal : -_paymentsTotal, currency),
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
          _AddRow(label: 'Add payment', accent: true, onTap: _addPayment),
          const SizedBox(height: 16),

          _BalanceBanner(remainingCents: _remainingCents, balanced: _balanced, currency: currency),
          const SizedBox(height: 16),
          PrimarySaveButton(label: 'Save', enabled: _canSave, loading: _submitting, onTap: _save),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle, required this.total});

  final String title;
  final String subtitle;
  final String total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    return Row(
      children: [
        Text(title, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Expanded(child: Text(subtitle, style: theme.textTheme.labelSmall?.copyWith(color: muted))),
        Text(
          total,
          style: theme.textTheme.titleSmall?.copyWith(
            fontFamily: CalmTokens.fontDisplay, fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.isIncome, required this.currency, required this.onDelete});

  final _ItemDraft item;
  final bool isIncome;
  final String currency;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    final magnitude = isIncome ? item.amount : -item.amount;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 9, height: 9,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: item.categoryId != null
                  ? CategoryPalette.forId(item.categoryId!).of(context)
                  : tokens.line,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.description ?? 'Item',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                if (item.categoryName != null)
                  Text(item.categoryName!,
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.55))),
              ],
            ),
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
            child: Text(_monthYear(payment.dueDate), style: theme.textTheme.bodyMedium),
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

class _BalanceBanner extends StatelessWidget {
  const _BalanceBanner({required this.remainingCents, required this.balanced, required this.currency});

  final int remainingCents;
  final bool balanced;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    // Nothing to balance yet (empty, or one side still empty at zero) reads as a
    // neutral prompt, not an error.
    final neutral = !balanced && remainingCents == 0;
    final color = balanced
        ? tokens.sage
        : neutral
            ? theme.colorScheme.onSurface.withValues(alpha: 0.55)
            : tokens.clay;
    final icon = balanced
        ? Icons.check_circle_outline
        : neutral
            ? Icons.info_outline
            : Icons.error_outline;
    final text = balanced
        ? 'Balanced — ${formatMagnitude(0, currency)} left'
        : neutral
            ? 'Add items and payments that balance'
            : remainingCents > 0
                ? '${formatMagnitude(remainingCents / 100, currency)} still to schedule'
                : '${formatMagnitude(remainingCents / 100, currency)} over — remove a payment';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(CalmTokens.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 9),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface))),
        ],
      ),
    );
  }
}

// ---- add-item / add-payment composers ----

Future<_ItemDraft?> _showItemComposer(BuildContext context, List<Category> categories) {
  final amountCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  String? categoryId;
  String? categoryName;

  return showModalBottomSheet<_ItemDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheet) {
        final amount = double.tryParse(amountCtrl.text.trim());
        final valid = amount != null && amount > 0;
        return SheetContainer(
          bottomSheet: true,
          title: 'Add item',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ComposerAmount(controller: amountCtrl, onChanged: () => setSheet(() {})),
              const SizedBox(height: 12),
              SheetTextField(controller: descCtrl, hint: 'What is it?  e.g. Base game'),
              const SizedBox(height: 12),
              PickerButton(
                label: 'Category',
                value: categoryName ?? 'Category',
                muted: categoryName == null,
                dotColor: categoryId != null ? CategoryPalette.forId(categoryId!).of(context) : null,
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
                label: 'Add item',
                enabled: valid,
                onTap: () => Navigator.of(context).pop(_ItemDraft(
                  amount: amount!,
                  categoryId: categoryId,
                  categoryName: categoryName,
                  description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
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
        return SheetContainer(
          bottomSheet: true,
          title: 'Add payment',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PickerButton(
                label: 'Date',
                value: _monthYear(date),
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
              _ComposerAmount(controller: amountCtrl, onChanged: () => setSheet(() {})),
              const SizedBox(height: 18),
              PrimarySaveButton(
                label: 'Add payment',
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

/// A plain numeric field for the composers (no sign/currency chrome — the parent
/// section already states direction and currency).
class _ComposerAmount extends StatelessWidget {
  const _ComposerAmount({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

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
        prefixText: 'Amount  ',
        hintText: '0.00',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(CalmTokens.radiusSm)),
      ),
    );
  }
}

String _monthYear(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[date.month - 1]} ${date.year}';
}

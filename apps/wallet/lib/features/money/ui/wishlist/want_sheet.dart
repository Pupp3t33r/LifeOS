import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/calm_tokens.dart';
import '../../../../app/theme/category_colors.dart';
import '../../../../shared/uuid.dart';
import '../../application/categories_providers.dart';
import '../../application/preferences_providers.dart';
import '../../data/outbox/wishlist_outbox.dart';
import '../../domain/category.dart';
import '../../domain/unit_dimension.dart';
import '../../domain/wishlist_item.dart';
import '../recurring/create_widgets.dart';
import '../recurring/recurring_shared.dart';
import '../recurring/sheet_container.dart';

/// Opens the **Add want** sheet (Money ADR-0022/0034/0036). Name is required;
/// estimate is optional; the category picker offers user categories only (system/
/// domain ones arrive with linking); unit dimension shows for Repeat (One-time
/// implies Pieces).
Future<void> showAddWant(BuildContext context) {
  return showMoneySheet(context, (bottomSheet) => _WantSheet(bottomSheet: bottomSheet));
}

/// Opens the **Edit want** sheet — same fields pre-filled, plus a read-only stage
/// banner (status is derived, never hand-edited) and a Remove action. Removing a
/// committed want does not cascade: its planned buy keeps its line but stops
/// tracking the want; nothing's been paid, so no money is affected.
Future<void> showEditWant(BuildContext context, WishlistItem want) {
  return showMoneySheet(
    context,
    (bottomSheet) => _WantSheet(bottomSheet: bottomSheet, existing: want),
  );
}

class _WantSheet extends ConsumerStatefulWidget {
  const _WantSheet({required this.bottomSheet, this.existing});

  final bool bottomSheet;
  final WishlistItem? existing;

  @override
  ConsumerState<_WantSheet> createState() => _WantSheetState();
}

class _WantSheetState extends ConsumerState<_WantSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _notesCtrl;
  late String _currency;
  String? _categoryId;
  String? _categoryName;
  late WishlistRecurrence _recurrence;
  UnitDimension? _unitDimension;
  bool _submitting = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final defaultCurrency =
        ref.read(preferencesProvider).value?.displayCurrency ?? 'USD';
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _amountCtrl = TextEditingController(
        text: e?.estimate == null ? '' : e!.estimate!.amount.toString());
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _currency = e?.estimate?.currency ?? defaultCurrency;
    _categoryId = e?.categoryId;
    _categoryName = e?.categoryId == null ? null : _resolveCategoryName(e!.categoryId!);
    _recurrence = e?.recurrence ?? WishlistRecurrence.once;
    _unitDimension = e?.defaultUnitDimension;

    _nameCtrl.addListener(() => setState(() {}));
    _amountCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SheetContainer(
      bottomSheet: widget.bottomSheet,
      icon: _isEdit ? Icons.edit_outlined : Icons.bookmark_add_outlined,
      title: _isEdit ? 'Edit want' : 'Add want',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isEdit) ...[
            _StageBanner(want: widget.existing!),
            const SizedBox(height: 16),
          ],
          const _FieldLabel('Name'),
          const SizedBox(height: 6),
          SheetTextField(controller: _nameCtrl, hint: 'What do you want?'),
          const SizedBox(height: 16),

          const _FieldLabel('Estimate (optional)'),
          const SizedBox(height: 6),
          MoneyAmountField(
            controller: _amountCtrl,
            isIncome: false,
            currency: _currency,
            onCurrencyTap: () async {
              final picked = await pickCurrency(context, selected: _currency);
              if (picked != null) setState(() => _currency = picked);
            },
            big: false,
          ),
          const SizedBox(height: 16),

          const _FieldLabel('Category'),
          const SizedBox(height: 6),
          PickerButton(
            label: 'Category',
            value: _categoryName ?? 'None',
            dotColor: _categoryId == null
                ? null
                : CategoryColors.slotFor(_categoryId!).resolve(theme.brightness),
            muted: _categoryId == null,
            onTap: () async {
              final userCats = _userCategories();
              final picked = await pickCategory(
                context,
                userCats,
                selectedId: _categoryId,
              );
              if (picked != null) {
                setState(() {
                  _categoryId = picked.id.isEmpty ? null : picked.id;
                  _categoryName = picked.id.isEmpty ? null : picked.name;
                });
              }
            },
          ),
          const SizedBox(height: 16),

          const _FieldLabel('Recurrence'),
          const SizedBox(height: 6),
          _RecurrencePicker(
            value: _recurrence,
            onChanged: (v) => setState(() {
              _recurrence = v;
              if (v == WishlistRecurrence.once) _unitDimension = null;
            }),
          ),
          if (_recurrence == WishlistRecurrence.reusable) ...[
            const SizedBox(height: 16),
            const _FieldLabel('Unit'),
            const SizedBox(height: 6),
            PickerButton(
              label: 'Unit',
              value: _unitLabel(_unitDimension),
              onTap: () => _pickUnitDimension(),
            ),
          ],
          const SizedBox(height: 16),

          const _FieldLabel('Notes (optional)'),
          const SizedBox(height: 6),
          SheetTextField(controller: _notesCtrl, hint: 'Anything to remember…'),
          const SizedBox(height: 24),

          PrimarySaveButton(
            label: _isEdit ? 'Save changes' : 'Add want',
            enabled: _canSave,
            loading: _submitting,
            onTap: _save,
          ),
          if (_isEdit) ...[
            const SizedBox(height: 10),
            _RemoveButton(onTap: _confirmRemove),
          ],
        ],
      ),
    );
  }

  bool get _canSave =>
      _nameCtrl.text.trim().isNotEmpty && !_submitting;

  double? get _amount {
    final v = double.tryParse(_amountCtrl.text.trim());
    return (v != null && v > 0) ? v : null;
  }

  List<Category> _userCategories() {
    final all = ref.read(categoriesProvider).value ?? const <Category>[];
    return [for (final c in all) if (!c.isSystem && !c.archived) c];
  }

  String _resolveCategoryName(String id) {
    final all = ref.read(categoriesProvider).value ?? const <Category>[];
    for (final c in all) {
      if (c.id == id) return c.name;
    }
    return '—';
  }

  String _unitLabel(UnitDimension? d) => switch (d) {
        null || UnitDimension.pieces => 'Pieces',
        UnitDimension.mass => 'Mass (kg / lb)',
        UnitDimension.volume => 'Volume (L / gal)',
        UnitDimension.length => 'Length (m / ft)',
      };

  Future<void> _pickUnitDimension() async {
    final picked = await showModalBottomSheet<UnitDimension>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(CalmTokens.radiusLg)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final d in UnitDimension.values)
              ListTile(
                title: Text(_unitLabel(d)),
                trailing: _unitDimension == d ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(d),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _unitDimension = picked);
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _submitting = true);

    final outbox = ref.read(wishlistOutboxProvider);
    final amount = _amount;

    if (_isEdit) {
      final e = widget.existing!;
      await outbox.editItem(
        id: e.id,
        recurrence: _recurrence,
        name: _nameCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        estimateAmount: amount,
        estimateCurrency: amount == null ? null : _currency,
        categoryId: _categoryId,
        defaultUnitDimension:
            _recurrence == WishlistRecurrence.reusable ? _unitDimension : null,
      );
    } else {
      await outbox.createItem(
        id: newUuidV4(),
        recurrence: _recurrence,
        name: _nameCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        estimateAmount: amount,
        estimateCurrency: amount == null ? null : _currency,
        categoryId: _categoryId,
        defaultUnitDimension:
            _recurrence == WishlistRecurrence.reusable ? _unitDimension : null,
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isEdit ? 'Want saved' : 'Want added')),
    );
  }

  Future<void> _confirmRemove() async {
    final e = widget.existing!;
    final committed = e.status != WishlistCommitment.idle;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove want?'),
        content: Text(committed
            ? '“${e.name ?? 'This want'}” will be removed from your wishlist. Its planned buy '
                'keeps its line but stops tracking the want. Nothing has been paid, so no '
                'money is affected.'
            : '“${e.name ?? 'This want'}” will be removed from your wishlist.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(wishlistOutboxProvider).deleteItem(id: e.id);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Want removed')),
    );
  }
}

class _StageBanner extends StatelessWidget {
  const _StageBanner({required this.want});

  final WishlistItem want;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    final brightness = theme.brightness;
    final color = switch (want.status) {
      WishlistCommitment.idle => tokens.muted,
      WishlistCommitment.planned => tokens.clay,
      WishlistCommitment.financed => CategoryPalette.denim.resolve(brightness),
      WishlistCommitment.bought => tokens.sage,
    };
    final label = switch (want.status) {
      WishlistCommitment.idle => 'Wishing',
      WishlistCommitment.planned => 'Planned',
      WishlistCommitment.financed => 'Paying off',
      WishlistCommitment.bought => 'Bought',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(CalmTokens.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Status: $label — derived, changed by planning or buying.',
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).hintColor,
          ),
    );
  }
}

class _RecurrencePicker extends StatelessWidget {
  const _RecurrencePicker({required this.value, required this.onChanged});

  final WishlistRecurrence value;
  final ValueChanged<WishlistRecurrence> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
      ),
      child: Row(
        children: [
          _segment(context, 'One-time', WishlistRecurrence.once),
          _segment(context, 'Repeat', WishlistRecurrence.reusable),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, String label, WishlistRecurrence v) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    final selected = v == value;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
        onTap: () => onChanged(v),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? theme.colorScheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
            boxShadow: selected
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.09), blurRadius: 3, offset: const Offset(0, 1))]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (v == WishlistRecurrence.reusable) ...[
                Icon(Icons.repeat, size: 13, color: selected ? tokens.sageDeep : null),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? (v == WishlistRecurrence.reusable ? tokens.sageDeep : theme.colorScheme.onSurface)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.delete_outline, size: 18),
        label: const Text('Remove want'),
        style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
      ),
    );
  }
}

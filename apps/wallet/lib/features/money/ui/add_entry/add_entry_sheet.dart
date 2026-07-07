import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/calm_tokens.dart';
import '../../../../app/theme/category_colors.dart';
import '../../application/categories_providers.dart';
import '../../application/preferences_providers.dart';
import '../../data/outbox/record_flow.dart';
import '../../domain/category.dart';
import '../../domain/currencies.dart';

/// Currency codes offered in the entry sheet (the shared pool).
const List<String> _currencies = kCurrencyPool;

/// Opens the add-entry surface: a bottom sheet on phones, a centred dialog on wide
/// screens. The sheet records an ad-hoc expense or income as a flow on the active
/// period (ADR-0016) via the outbox.
Future<void> showAddEntry(BuildContext context) {
  final wide = MediaQuery.sizeOf(context).width >= 700;
  if (wide) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 780),
          child: const AddEntrySheet(bottomSheet: false),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const AddEntrySheet(bottomSheet: true),
  );
}

enum _Direction { expense, income }

/// A line being assembled in the sheet (positive [amount] magnitude; the entry
/// direction supplies the sign at commit).
class _DraftLine {
  _DraftLine({required this.amount, this.categoryId, this.categoryName, this.description});

  double amount;
  String? categoryId;
  String? categoryName;
  String? description;
}

class AddEntrySheet extends ConsumerStatefulWidget {
  const AddEntrySheet({super.key, required this.bottomSheet});

  final bool bottomSheet;

  @override
  ConsumerState<AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends ConsumerState<AddEntrySheet> {
  _Direction _direction = _Direction.expense;
  String? _currency;
  DateTime _occurredAt = DateTime.now();

  final List<_DraftLine> _lines = [];
  bool _promoted = false;
  int? _editingIndex;
  bool _submitting = false;

  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _entryNameCtrl = TextEditingController();
  String? _categoryId;
  String? _categoryName;

  bool get _isIncome => _direction == _Direction.income;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _entryNameCtrl.dispose();
    super.dispose();
  }

  String _effectiveCurrency(WidgetRef ref) =>
      _currency ?? ref.watch(preferencesProvider).value?.displayCurrency ?? 'USD';

  double get _committedTotal => _lines.fold(0, (sum, x) => sum + x.amount);

  /// The composer's current draft as a line, or null if there's no valid amount.
  _DraftLine? _readComposer() {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) return null;
    final desc = _descCtrl.text.trim();
    return _DraftLine(
      amount: amount,
      categoryId: _categoryId,
      categoryName: _categoryName,
      description: desc.isEmpty ? null : desc,
    );
  }

  bool get _canCommit => _lines.isNotEmpty || _readComposer() != null;

  void _clearComposer() {
    _amountCtrl.clear();
    _descCtrl.clear();
    _categoryId = null;
    _categoryName = null;
  }

  void _addOrSaveLine() {
    final line = _readComposer();
    if (line == null) return;
    setState(() {
      if (_editingIndex != null) {
        _lines[_editingIndex!] = line;
        _editingIndex = null;
      } else {
        _lines.add(line);
      }
      _promoted = true;
      _clearComposer();
    });
  }

  void _editLine(int index) {
    final line = _lines[index];
    setState(() {
      _amountCtrl.text = _fmt(line.amount);
      _descCtrl.text = line.description ?? '';
      _categoryId = line.categoryId;
      _categoryName = line.categoryName;
      _editingIndex = index;
    });
  }

  void _deleteLine(int index) {
    setState(() {
      _lines.removeAt(index);
      if (_editingIndex == index) {
        _editingIndex = null;
        _clearComposer();
      }
    });
  }

  Future<void> _commit() async {
    final lines = [..._lines];
    final pending = _readComposer();
    if (pending != null) lines.add(pending);
    if (lines.isEmpty) return;

    setState(() => _submitting = true);
    final prefs = ref.read(preferencesProvider).value;
    final currency = _effectiveCurrency(ref);
    final description = _promoted
        ? (_entryNameCtrl.text.trim().isEmpty ? null : _entryNameCtrl.text.trim())
        : null;

    await ref.read(flowOutboxProvider).record(
          isIncome: _isIncome,
          currency: currency,
          occurredAt: _occurredAt,
          monthStartDay: prefs?.monthStartDay ?? 1,
          description: description,
          lines: [
            for (final line in lines)
              FlowLineDraft(
                amount: line.amount,
                categoryId: line.categoryId,
                description: line.description,
              ),
          ],
        );

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isIncome ? 'Income added' : 'Expense added')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.bottomSheet) _grip(theme),
          _header(theme),
          const SizedBox(height: 14),
          _directionToggle(theme),
          const SizedBox(height: 16),
          if (!_promoted) ..._singleLine(theme) else ..._multiLine(theme),
          const SizedBox(height: 18),
          _commitButton(theme),
          if (!widget.bottomSheet) const SizedBox(height: 2),
        ],
      ),
    );

    final scroll = SingleChildScrollView(child: content);

    if (!widget.bottomSheet) return scroll;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(CalmTokens.radiusLg)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: scroll,
        ),
      ),
    );
  }

  Widget _grip(ThemeData theme) => Center(
        child: Container(
          width: 38,
          height: 5,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
          ),
        ),
      );

  Widget _header(ThemeData theme) {
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Row(
      children: [
        Expanded(
          child: Text(
            _isIncome ? 'NEW INCOME' : 'NEW EXPENSE',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: muted, letterSpacing: 1.8, fontWeight: FontWeight.w600),
          ),
        ),
        InkWell(
          onTap: () => Navigator.of(context).maybePop(),
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.close, size: 18, color: muted),
          ),
        ),
      ],
    );
  }

  Widget _directionToggle(ThemeData theme) {
    Widget seg(String label, _Direction value) {
      final selected = _direction == value;
      final color = value == _Direction.income
          ? CalmTokens.of(theme.brightness).sageDeep
          : theme.colorScheme.secondary;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _direction = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: selected ? theme.colorScheme.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
              boxShadow: selected
                  ? [BoxShadow(color: theme.colorScheme.shadow.withValues(alpha: 0.08), blurRadius: 3, offset: const Offset(0, 1))]
                  : null,
            ),
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: selected ? color : theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
      ),
      child: Row(children: [seg('Expense', _Direction.expense), seg('Income', _Direction.income)]),
    );
  }

  // ---- single-line (opening) -------------------------------------------------

  List<Widget> _singleLine(ThemeData theme) {
    return [
      _heroAmountField(theme),
      const SizedBox(height: 10),
      Center(child: _currencyChip(theme)),
      const SizedBox(height: 18),
      _textField(theme, _descCtrl, 'What was it?  e.g. Lidl'),
      const SizedBox(height: 12),
      _pickRows(theme, includeCurrency: false),
      const SizedBox(height: 14),
      _addAnotherLine(theme),
    ];
  }

  Widget _heroAmountField(ThemeData theme) {
    final accent = _isIncome
        ? CalmTokens.of(theme.brightness).sageDeep
        : theme.colorScheme.secondary;
    final numStyle = theme.textTheme.displaySmall?.copyWith(
      fontFamily: CalmTokens.fontDisplay,
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurface,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(_isIncome ? '+ ' : '− ', style: numStyle?.copyWith(color: accent, fontWeight: FontWeight.w400)),
          IntrinsicWidth(
            child: TextField(
              controller: _amountCtrl,
              autofocus: true,
              textAlign: TextAlign.left,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: numStyle,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: '0.00',
                hintStyle: numStyle?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.25)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addAnotherLine(ThemeData theme) {
    final sage = CalmTokens.of(theme.brightness).sageDeep;
    final enabled = _readComposer() != null;
    return InkWell(
      onTap: enabled ? _addOrSaveLine : null,
      borderRadius: BorderRadius.circular(CalmTokens.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(CalmTokens.radiusMd),
          border: Border.all(
            color: enabled ? sage.withValues(alpha: 0.5) : theme.colorScheme.outline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 16, color: enabled ? sage : theme.colorScheme.onSurface.withValues(alpha: 0.4)),
            const SizedBox(width: 8),
            Text(
              'Add another line',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: enabled ? sage : theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- multi-line (promoted) -------------------------------------------------

  List<Widget> _multiLine(ThemeData theme) {
    final accent = _isIncome
        ? CalmTokens.of(theme.brightness).sageDeep
        : theme.colorScheme.secondary;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return [
      Center(
        child: Text(
          '${_isIncome ? '+' : '−'} ${_fmt(_committedTotal)}',
          style: theme.textTheme.displaySmall?.copyWith(
            fontFamily: CalmTokens.fontDisplay,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
      const SizedBox(height: 6),
      Center(
        child: Text(
          'TOTAL · ${_lines.length} ${_lines.length == 1 ? 'item' : 'items'}',
          style: theme.textTheme.labelSmall?.copyWith(color: muted, letterSpacing: 1.4, fontWeight: FontWeight.w600),
        ),
      ),
      const SizedBox(height: 16),
      _pickRows(theme, includeCurrency: true),
      const SizedBox(height: 12),
      _textField(theme, _entryNameCtrl, 'Name this entry — optional'),
      const SizedBox(height: 12),
      _itemsList(theme, accent),
      const SizedBox(height: 10),
      _composer(theme),
    ];
  }

  Widget _itemsList(ThemeData theme, Color accent) {
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(CalmTokens.radiusMd),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _lines.length; i++) ...[
            if (i > 0) Divider(height: 1, color: theme.colorScheme.outline),
            _lineRow(theme, i, accent, muted),
          ],
        ],
      ),
    );
  }

  Widget _lineRow(ThemeData theme, int index, Color accent, Color muted) {
    final line = _lines[index];
    final editing = _editingIndex == index;
    final dotColor = line.categoryId == null
        ? null
        : CategoryPalette.forId(line.categoryId!).resolve(theme.brightness);
    return Container(
      color: editing ? CalmTokens.of(theme.brightness).sageDeep.withValues(alpha: 0.08) : null,
      padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
      child: Row(
        children: [
          Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
              border: dotColor == null ? Border.all(color: theme.colorScheme.outline, width: 1.4) : null,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.description ?? (line.categoryName ?? 'Line ${index + 1}'),
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface),
                  overflow: TextOverflow.ellipsis,
                ),
                if (line.categoryName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(line.categoryName!, style: theme.textTheme.labelSmall?.copyWith(color: muted)),
                  ),
              ],
            ),
          ),
          Text(
            '${_isIncome ? '+' : '−'}${_fmt(line.amount)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: CalmTokens.fontDisplay,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            color: muted,
            onPressed: () => _editLine(index),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            color: muted,
            onPressed: () => _deleteLine(index),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }

  Widget _composer(ThemeData theme) {
    final sage = CalmTokens.of(theme.brightness).sageDeep;
    final editing = _editingIndex != null;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: editing ? sage : theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(CalmTokens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  editing ? 'EDITING LINE' : 'ADD A LINE',
                  style: theme.textTheme.labelSmall?.copyWith(color: muted, letterSpacing: 1.4, fontWeight: FontWeight.w600),
                ),
              ),
              if (editing)
                GestureDetector(
                  onTap: () => setState(() {
                    _editingIndex = null;
                    _clearComposer();
                  }),
                  child: Text('Cancel', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.secondary, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontFamily: CalmTokens.fontDisplay, fontWeight: FontWeight.w600),
                  decoration: _decoration(theme, '0.00', prefix: '\$ '),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _categorySelector(theme)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _descCtrl,
                  style: theme.textTheme.bodyMedium,
                  decoration: _decoration(theme, 'Description'),
                ),
              ),
              const SizedBox(width: 8),
              _addButton(theme, sage, editing),
            ],
          ),
        ],
      ),
    );
  }

  Widget _addButton(ThemeData theme, Color sage, bool editing) {
    final enabled = _readComposer() != null;
    return Material(
      color: enabled ? sage.withValues(alpha: 0.10) : theme.colorScheme.onSurface.withValues(alpha: 0.04),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: enabled ? sage : theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(CalmTokens.radiusSm),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? _addOrSaveLine : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            editing ? 'Save' : '＋ Add',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: enabled ? sage : theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }

  // ---- shared rows -----------------------------------------------------------

  Widget _pickRows(ThemeData theme, {required bool includeCurrency}) {
    final rows = <Widget>[
      if (!_promoted) _categoryRow(theme),
      _whenRow(theme),
      if (includeCurrency) _currencyRow(theme),
    ];
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(CalmTokens.radiusMd),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: theme.colorScheme.outline),
            rows[i],
          ],
        ],
      ),
    );
  }

  Widget _row(ThemeData theme, IconData icon, String label, Widget value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
            value,
            const SizedBox(width: 6),
            Icon(Icons.expand_more, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _categoryRow(ThemeData theme) {
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final Widget value = _categoryId == null
        ? Text('Optional', style: theme.textTheme.bodyMedium?.copyWith(color: muted))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: CategoryPalette.forId(_categoryId!).resolve(theme.brightness),
                ),
              ),
              const SizedBox(width: 7),
              Text(_categoryName ?? '', style: theme.textTheme.bodyMedium),
            ],
          );
    return _row(theme, Icons.sell_outlined, 'Category', value, _pickCategory);
  }

  Widget _whenRow(ThemeData theme) {
    return _row(
      theme,
      Icons.calendar_today_outlined,
      'When',
      Text(_dateLabel(_occurredAt), style: theme.textTheme.bodyMedium),
      _pickDate,
    );
  }

  Widget _currencyRow(ThemeData theme) {
    return _row(
      theme,
      Icons.payments_outlined,
      'Currency',
      Text(
        _effectiveCurrency(ref),
        style: theme.textTheme.bodyMedium?.copyWith(fontFamily: CalmTokens.fontDisplay, fontWeight: FontWeight.w600),
      ),
      _pickCurrency,
    );
  }

  Widget _currencyChip(ThemeData theme) {
    return InkWell(
      onTap: _pickCurrency,
      borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _effectiveCurrency(ref),
              style: theme.textTheme.labelMedium?.copyWith(fontFamily: CalmTokens.fontDisplay, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _categorySelector(ThemeData theme) {
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return InkWell(
      onTap: _pickCategory,
      borderRadius: BorderRadius.circular(CalmTokens.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(CalmTokens.radiusSm),
        ),
        child: Row(
          children: [
            if (_categoryId != null) ...[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: CategoryPalette.forId(_categoryId!).resolve(theme.brightness)),
              ),
              const SizedBox(width: 7),
            ],
            Expanded(
              child: Text(
                _categoryName ?? 'Category',
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(color: _categoryName == null ? muted : theme.colorScheme.onSurface),
              ),
            ),
            Icon(Icons.expand_more, size: 16, color: muted),
          ],
        ),
      ),
    );
  }

  Widget _commitButton(ThemeData theme) {
    final label = _isIncome ? 'Add income' : 'Add expense';
    return FilledButton(
      onPressed: (_canCommit && !_submitting) ? _commit : null,
      child: _submitting
          ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
          : Text(label),
    );
  }

  // ---- inputs / pickers ------------------------------------------------------

  Widget _textField(ThemeData theme, TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      style: theme.textTheme.bodyMedium,
      decoration: _decoration(theme, hint),
    );
  }

  InputDecoration _decoration(ThemeData theme, String hint, {String? prefix}) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefix,
      isDense: true,
      filled: true,
      fillColor: CalmTokens.of(theme.brightness).bone,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CalmTokens.radiusSm),
        borderSide: BorderSide(color: theme.colorScheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CalmTokens.radiusSm),
        borderSide: BorderSide(color: theme.colorScheme.outline),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked != null) setState(() => _occurredAt = picked);
  }

  Future<void> _pickCurrency() async {
    final theme = Theme.of(context);
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final code in _currencies)
              ListTile(
                title: Text(code, style: const TextStyle(fontFamily: CalmTokens.fontDisplay, fontWeight: FontWeight.w600)),
                trailing: code == _effectiveCurrency(ref) ? Icon(Icons.check, color: theme.colorScheme.primary) : null,
                onTap: () => Navigator.of(context).pop(code),
              ),
          ],
        ),
      ),
    );
    if (selected != null) setState(() => _currency = selected);
  }

  Future<void> _pickCategory() async {
    final pick = await showModalBottomSheet<_CategoryChoice>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CategoryPicker(),
    );
    if (pick != null) {
      setState(() {
        _categoryId = pick.id;
        _categoryName = pick.name;
      });
    }
  }

  String _fmt(double value) => value.toStringAsFixed(2);

  String _dateLabel(DateTime date) {
    final today = DateTime.now();
    final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final label = '${months[date.month - 1]} ${date.day}';
    return isToday ? 'Today · $label' : label;
  }
}

/// The result of the category picker: a chosen category, or "None" (both fields
/// null). A null return from the sheet means dismissed-without-choosing.
class _CategoryChoice {
  const _CategoryChoice(this.id, this.name);

  final String? id;
  final String? name;
}

/// Category picker — the ADR-0024 overlay from [categoriesProvider] plus a "None"
/// option. System categories are marked. Pops a [_CategoryChoice].
class _CategoryPicker extends ConsumerWidget {
  const _CategoryPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final categories = ref.watch(categoriesProvider);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'CATEGORY',
                style: theme.textTheme.labelSmall?.copyWith(color: muted, letterSpacing: 1.6, fontWeight: FontWeight.w600),
              ),
            ),
            Flexible(
              child: categories.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('Couldn’t load categories.', style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
                ),
                data: (items) => ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      leading: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: theme.colorScheme.outline, width: 1.6)),
                      ),
                      title: Text('None', style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
                      onTap: () => Navigator.of(context).pop(const _CategoryChoice(null, null)),
                    ),
                    for (final category in items) _categoryTile(context, theme, muted, category),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryTile(BuildContext context, ThemeData theme, Color muted, Category category) {
    return ListTile(
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(shape: BoxShape.circle, color: CategoryPalette.forId(category.id).resolve(theme.brightness)),
      ),
      title: Text(category.name, style: theme.textTheme.bodyMedium),
      trailing: category.isSystem
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 13, color: muted),
                const SizedBox(width: 4),
                Text('system', style: theme.textTheme.labelSmall?.copyWith(color: muted)),
              ],
            )
          : null,
      onTap: () => Navigator.of(context).pop(_CategoryChoice(category.id, category.name)),
    );
  }
}

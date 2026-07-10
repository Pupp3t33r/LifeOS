import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/calm_tokens.dart';
import '../../application/budget_providers.dart';
import '../../application/categories_providers.dart';
import '../../application/preferences_providers.dart';
import '../../application/recurring_providers.dart';
import '../../application/selected_period_providers.dart';
import '../../data/outbox/budget_outbox.dart';
import '../../domain/category.dart';
import '../../domain/recurring/recurring_payment.dart';
import '../recurring/recurring_shared.dart' show formatMagnitude, formatSigned, pickCategory;

const List<String> _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// The **Budget** view (Wallet ADR-0005 §5, Money ADR-0035) — set the month's shape: a
/// spending limit per tracked category + a savings target, with a plain-arithmetic "Your
/// month" readout (expected income − limits − target = free). The tracked list is an
/// opt-in subset of existing categories; untracked spend pools into Other on Home. This
/// view is the one Plan surface with a period control (limits/target persist per period).
class PlanBudgetView extends ConsumerStatefulWidget {
  const PlanBudgetView({super.key});

  @override
  ConsumerState<PlanBudgetView> createState() => _PlanBudgetViewState();
}

class _PlanBudgetViewState extends ConsumerState<PlanBudgetView> {
  ({int year, int month})? _period;
  String? _seededKey;
  String _target = '';
  Map<String, String> _limits = {};
  Set<String> _tracked = {};

  String get _key => '${_period!.year}-${_period!.month}';

  void _shift(int delta) {
    final p = _period!;
    final zeroBased = p.year * 12 + (p.month - 1) + delta;
    setState(() => _period = (year: zeroBased ~/ 12, month: zeroBased % 12 + 1));
  }

  double _sumLimits() {
    var total = 0.0;
    for (final id in _tracked) {
      total += double.tryParse(_limits[id] ?? '') ?? 0;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    _period ??= ref.watch(activePeriodProvider);
    final period = _period!;
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    final currency = ref.watch(preferencesProvider).value?.displayCurrency ?? 'USD';

    final budgetAsync = ref.watch(budgetProvider(period));
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];

    // Seed the editable state once per period, when the budget has loaded (mutating in
    // build is safe here — the same build renders from these values, later builds skip).
    budgetAsync.whenData((b) {
      if (_seededKey != _key) {
        _target = b.savingsTarget == null ? '' : _trim(b.savingsTarget!.amount);
        _limits = {for (final l in b.limits) l.categoryId: _trim(l.amount.amount)};
        _tracked = b.trackedCategories.toSet();
        _seededKey = _key;
      }
    });

    // Expected income ≈ Σ active Live income in the display currency (rough; FX ignored).
    final recurrings = ref.watch(recurringListProvider).value ?? const [];
    final expectedIncome = recurrings
        .where((x) => x.isActive && x.mode == ScheduleMode.live && x.isIncome
            && x.estimatedAmount?.currency == currency)
        .fold<double>(0, (sum, x) => sum + (x.estimatedAmount?.amount.toDouble() ?? 0));

    final byId = {for (final c in categories) c.id: c};
    final tracked = _tracked.where(byId.containsKey).toList()
      ..sort((a, b) => byId[a]!.name.toLowerCase().compareTo(byId[b]!.name.toLowerCase()));

    final target = double.tryParse(_target) ?? 0;
    final free = expectedIncome - _sumLimits() - target;

    return Column(
      children: [
        _periodBar(theme, tokens, period),
        Expanded(
          child: budgetAsync.isLoading && _seededKey != _key
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  children: [
                    _yourMonthCard(theme, tokens, currency, expectedIncome, target, free),
                    const SizedBox(height: 20),
                    Text('Savings target', style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    _amountField(
                      keyString: '$_key-target',
                      initial: _target,
                      currency: currency,
                      hint: 'How much to save this month',
                      onChanged: (v) => setState(() => _target = v),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Text('Spending limits', style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                        ),
                        TextButton.icon(
                          onPressed: () => _addCategory(categories),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Track a category'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (tracked.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('No categories tracked yet — add one to set a limit.',
                            style: theme.textTheme.bodyMedium?.copyWith(color: tokens.muted)),
                      )
                    else
                      for (final id in tracked)
                        _limitRow(theme, tokens, byId[id]!, currency),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => _save(period, currency),
                      child: const Text('Save budget'),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _periodBar(ThemeData theme, CalmTokens tokens, ({int year, int month}) period) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () => _shift(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          Text('${_monthNames[period.month - 1]} ${period.year}',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          IconButton(
            onPressed: () => _shift(1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _yourMonthCard(ThemeData theme, CalmTokens tokens, String currency,
      double income, double target, double free) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(CalmTokens.radiusMd),
        border: Border.all(color: tokens.line),
      ),
      child: Column(
        children: [
          _row(theme, tokens, 'Expected income', formatMagnitude(income, currency)),
          _row(theme, tokens, 'Spending limits', '−${formatMagnitude(_sumLimits(), currency)}'),
          _row(theme, tokens, 'Savings target', '−${formatMagnitude(target, currency)}'),
          const Divider(height: 20),
          _row(theme, tokens, 'Free to spend',
              formatSigned(free, currency), emphasise: true,
              color: free < 0 ? tokens.clay : tokens.sage),
        ],
      ),
    );
  }

  Widget _row(ThemeData theme, CalmTokens tokens, String label, String value,
      {bool emphasise = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium
              ?.copyWith(color: emphasise ? tokens.ink : tokens.muted,
                  fontWeight: emphasise ? FontWeight.w700 : FontWeight.w400))),
          Text(value, style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700, color: color ?? tokens.ink)),
        ],
      ),
    );
  }

  Widget _limitRow(ThemeData theme, CalmTokens tokens, Category category, String currency) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(category.name, style: theme.textTheme.bodyLarge)),
          SizedBox(
            width: 140,
            child: _amountField(
              keyString: '$_key-limit-${category.id}',
              initial: _limits[category.id] ?? '',
              currency: currency,
              hint: 'Limit',
              onChanged: (v) => setState(() => _limits[category.id] = v),
            ),
          ),
          IconButton(
            tooltip: 'Stop tracking',
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() {
              _tracked.remove(category.id);
              _limits.remove(category.id);
            }),
          ),
        ],
      ),
    );
  }

  Widget _amountField({
    required String keyString,
    required String initial,
    required String currency,
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    return TextFormField(
      key: ValueKey(keyString),
      initialValue: initial,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        isDense: true,
        prefixText: '$currency ',
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }

  Future<void> _addCategory(List<Category> categories) async {
    final available = categories.where((c) => !_tracked.contains(c.id)).toList();
    final chosen = await pickCategory(context, available);
    if (chosen == null || chosen.id.isEmpty) return;
    setState(() {
      _tracked.add(chosen.id);
      _limits.putIfAbsent(chosen.id, () => '');
    });
  }

  Future<void> _save(({int year, int month}) period, String currency) async {
    final limits = <BudgetLimitDraft>[];
    for (final id in _tracked) {
      final amount = double.tryParse(_limits[id] ?? '');
      if (amount != null && amount > 0) {
        limits.add(BudgetLimitDraft(categoryId: id, amount: amount, currency: currency));
      }
    }
    final target = double.tryParse(_target);
    await ref.read(budgetOutboxProvider).put(
          year: period.year,
          month: period.month,
          savingsTarget: target != null && target > 0 ? target : null,
          currency: currency,
          limits: limits,
          trackedCategories: _tracked.toList(),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Budget saved')),
    );
  }

  String _trim(num value) {
    final s = value.toString();
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }
}

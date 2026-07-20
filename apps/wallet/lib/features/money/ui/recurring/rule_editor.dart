import 'package:flutter/material.dart';
import '../../../../app/theme/calm_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/recurring/recurrence_rule.dart';
import 'recurring_shared.dart'
    show formatDayOfMonthAnchor, formatFullDate, formatMonthName, formatWeekday;

/// The **Repeats** block of the Ongoing sheet (create-ongoing design): the
/// Every / On / Ends controls that assemble a [RecurrenceRule]. Start is implicitly
/// today (occurrences fire on/after it); Ends offers only *Never* or *On a date* — a
/// countable end is a Payment plan. Emits the assembled rule via [onChanged], or null
/// when the selection is incomplete (a weekly with no weekday, a monthly with no day)
/// so the sheet can gate Save.
class RuleEditor extends StatefulWidget {
  const RuleEditor({super.key, required this.onChanged});

  final ValueChanged<RecurrenceRule?> onChanged;

  @override
  State<RuleEditor> createState() => _RuleEditorState();
}

enum _Unit { day, week, month, year }

class _RuleEditorState extends State<RuleEditor> {
  final DateTime _today = DateTime.now();

  _Unit _unit = _Unit.month;
  int _interval = 1;

  // Weekly (.NET DayOfWeek ints: Sun=0 … Sat=6).
  late final Set<int> _weekdays = {_netWeekday(_today.weekday)};

  // Monthly.
  late final Set<int> _monthDays = {_curatedDays.contains(_today.day) ? _today.day : 1};
  bool _lastDay = false;

  // Yearly.
  late int _yearMonth = _today.month;
  late int _yearDay = _today.day;

  // Ends.
  bool _endsOnDate = false;
  late DateTime _endDate = DateTime(_today.year + 1, _today.month, _today.day);

  static const List<int> _curatedDays = [1, 5, 10, 15, 20, 25, 28];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  static int _netWeekday(int dartWeekday) => dartWeekday == DateTime.sunday ? 0 : dartWeekday;

  RecurrenceRule? _build() {
    final start = DateTime(_today.year, _today.month, _today.day);
    final RecurrenceEnd end = _endsOnDate ? EndsOnDate(date: _endDate) : const NeverEnds();
    switch (_unit) {
      case _Unit.day:
        return DailyRule(start: start, end: end, intervalDays: _interval);
      case _Unit.week:
        if (_weekdays.isEmpty) return null;
        return WeeklyRule(
          start: start, end: end, intervalWeeks: _interval,
          weekdays: _weekdays.toList()..sort(),
        );
      case _Unit.month:
        final anchors = <MonthDayAnchor>[
          for (final d in _monthDays.toList()..sort()) OnDayOfMonth(day: d),
          if (_lastDay) const LastDayOfMonth(),
        ];
        if (anchors.isEmpty) return null;
        return MonthlyRule(start: start, end: end, intervalMonths: _interval, days: anchors);
      case _Unit.year:
        return YearlyRule(
          start: start, end: end, intervalYears: _interval,
          dates: [AnnualDate(month: _yearMonth, day: _yearDay)],
        );
    }
  }

  void _emit() => widget.onChanged(_build());

  void _set(VoidCallback change) {
    setState(change);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _divider(context, l10n.ruleEditorRepeatsLabel),
        _row(context, l10n.ruleEditorEveryLabel, _everyControl(context)),
        if (_onControl(context, l10n) case final on?) ...[
          const SizedBox(height: 10),
          _labelled(context, _onLabel(l10n), on),
        ],
        const SizedBox(height: 10),
        _row(context, l10n.ruleEditorEndsLabel, _endsControl(context, l10n)),
      ],
    );
  }

  String _onLabel(AppLocalizations l10n) => switch (_unit) {
        _Unit.week => l10n.ruleEditorOnLabel,
        _Unit.month => l10n.ruleEditorOnDayLabel,
        _Unit.year => l10n.ruleEditorOnLabel,
        _Unit.day => '',
      };

  Widget _everyControl(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 7,
          children: [
            for (final unit in _Unit.values)
              _chip(
                context,
                _unitLabel(l10n, unit),
                selected: _unit == unit,
                onTap: () => _set(() => _unit = unit),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(l10n.ruleEditorEveryWord, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: 10),
            _StepperControl(
              value: _interval,
              min: 1,
              onChanged: (v) => _set(() => _interval = v),
            ),
            const SizedBox(width: 8),
            Text(_unitPlural(l10n, _unit), style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ],
    );
  }

  Widget? _onControl(BuildContext context, AppLocalizations l10n) {
    switch (_unit) {
      case _Unit.day:
        return null;
      case _Unit.week:
        final ints = [1, 2, 3, 4, 5, 6, 0];
        return Wrap(
          spacing: 7, runSpacing: 7,
          children: [
            for (final n in ints)
              _chip(
                context, formatWeekday(context, n),
                selected: _weekdays.contains(n),
                onTap: () => _set(() =>
                    _weekdays.contains(n) ? _weekdays.remove(n) : _weekdays.add(n)),
              ),
          ],
        );
      case _Unit.month:
        return Wrap(
          spacing: 7, runSpacing: 7,
          children: [
            for (final d in _curatedDays)
              _chip(
                context, formatDayOfMonthAnchor(context, d),
                selected: _monthDays.contains(d),
                onTap: () => _set(() =>
                    _monthDays.contains(d) ? _monthDays.remove(d) : _monthDays.add(d)),
              ),
            _chip(
              context, l10n.ruleEditorLastDay,
              selected: _lastDay,
              onTap: () => _set(() => _lastDay = !_lastDay),
            ),
          ],
        );
      case _Unit.year:
        return Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _yearMonth,
                isDense: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: [
                  for (var m = 1; m <= 12; m++)
                    DropdownMenuItem(
                      value: m,
                      child: Text(formatMonthName(context, m)),
                    ),
                ],
                onChanged: (v) => _set(() => _yearMonth = v ?? _yearMonth),
              ),
            ),
            const SizedBox(width: 10),
            _StepperControl(
              value: _yearDay, min: 1, max: 31,
              onChanged: (v) => _set(() => _yearDay = v),
            ),
          ],
        );
    }
  }

  Widget _endsControl(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _chip(context, l10n.ruleEditorNever, selected: !_endsOnDate, onTap: () => _set(() => _endsOnDate = false)),
            const SizedBox(width: 7),
            _chip(context, l10n.ruleEditorOnADate, selected: _endsOnDate, onTap: () => _set(() => _endsOnDate = true)),
          ],
        ),
        if (_endsOnDate) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: Text(formatFullDate(context, _endDate)),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _endDate,
                  firstDate: _today,
                  lastDate: DateTime(_today.year + 20),
                );
                if (picked != null) _set(() => _endDate = picked);
              },
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            l10n.ruleEditorCountableEndNote,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      ],
    );
  }

  // ---- small shared bits ----

  Widget _divider(BuildContext context, String label) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: Row(
        children: [
          Text(
            '↻ ${label.toUpperCase()}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: tokens.sageDeep, fontWeight: FontWeight.w700, letterSpacing: 1.1,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, Widget control) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 6),
        control,
      ],
    );
  }

  Widget _labelled(BuildContext context, String label, Widget control) =>
      label.isEmpty ? control : _row(context, label, control);

  Widget _chip(BuildContext context, String label,
      {required bool selected, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    return InkWell(
      borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? tokens.sage.withValues(alpha: 0.14) : theme.colorScheme.surface,
          border: Border.all(color: selected ? tokens.sage : theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: selected ? tokens.sageDeep : theme.colorScheme.onSurface,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  static String _unitLabel(AppLocalizations l10n, _Unit unit) => switch (unit) {
        _Unit.day => l10n.ruleEditorUnitDay,
        _Unit.week => l10n.ruleEditorUnitWeek,
        _Unit.month => l10n.ruleEditorUnitMonth,
        _Unit.year => l10n.ruleEditorUnitYear,
      };

  static String _unitPlural(AppLocalizations l10n, _Unit unit) => switch (unit) {
        _Unit.day => l10n.ruleEditorUnitDayPlural,
        _Unit.week => l10n.ruleEditorUnitWeekPlural,
        _Unit.month => l10n.ruleEditorUnitMonthPlural,
        _Unit.year => l10n.ruleEditorUnitYearPlural,
      };
}

/// A compact −/N/+ stepper.
class _StepperControl extends StatelessWidget {
  const _StepperControl({
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 999,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget button(IconData icon, VoidCallback? onTap) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
          child: Container(
            width: 30, height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 17, color: theme.colorScheme.primary),
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(Icons.remove, value > min ? () => onChanged(value - 1) : null),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '$value',
            style: theme.textTheme.titleSmall?.copyWith(
              fontFamily: CalmTokens.fontDisplay, fontWeight: FontWeight.w600,
            ),
          ),
        ),
        button(Icons.add, value < max ? () => onChanged(value + 1) : null),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../app/theme/calm_tokens.dart';
import '../../domain/recurring/recurrence_rule.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _divider(context, 'Repeats'),
        _row(context, 'Every', _everyControl(context)),
        if (_onControl(context) case final on?) ...[
          const SizedBox(height: 10),
          _labelled(context, _onLabel, on),
        ],
        const SizedBox(height: 10),
        _row(context, 'Ends', _endsControl(context)),
      ],
    );
  }

  String get _onLabel => switch (_unit) {
        _Unit.week => 'On',
        _Unit.month => 'On day',
        _Unit.year => 'On',
        _Unit.day => '',
      };

  Widget _everyControl(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 7,
          children: [
            for (final unit in _Unit.values)
              _chip(
                context,
                _unitLabel(unit),
                selected: _unit == unit,
                onTap: () => _set(() => _unit = unit),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text('every', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: 10),
            _StepperControl(
              value: _interval,
              min: 1,
              onChanged: (v) => _set(() => _interval = v),
            ),
            const SizedBox(width: 8),
            Text(_unitPlural(_unit), style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ],
    );
  }

  Widget? _onControl(BuildContext context) {
    switch (_unit) {
      case _Unit.day:
        return null;
      case _Unit.week:
        const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        const ints = [1, 2, 3, 4, 5, 6, 0];
        return Wrap(
          spacing: 7, runSpacing: 7,
          children: [
            for (var i = 0; i < labels.length; i++)
              _chip(
                context, labels[i],
                selected: _weekdays.contains(ints[i]),
                onTap: () => _set(() =>
                    _weekdays.contains(ints[i]) ? _weekdays.remove(ints[i]) : _weekdays.add(ints[i])),
              ),
          ],
        );
      case _Unit.month:
        return Wrap(
          spacing: 7, runSpacing: 7,
          children: [
            for (final d in _curatedDays)
              _chip(
                context, _ordinal(d),
                selected: _monthDays.contains(d),
                onTap: () => _set(() =>
                    _monthDays.contains(d) ? _monthDays.remove(d) : _monthDays.add(d)),
              ),
            _chip(
              context, 'Last day',
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
                    DropdownMenuItem(value: m, child: Text(_monthNames[m - 1])),
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

  Widget _endsControl(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _chip(context, 'Never', selected: !_endsOnDate, onTap: () => _set(() => _endsOnDate = false)),
            const SizedBox(width: 7),
            _chip(context, 'On a date', selected: _endsOnDate, onTap: () => _set(() => _endsOnDate = true)),
          ],
        ),
        if (_endsOnDate) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: Text('${_monthNames[_endDate.month - 1]} ${_endDate.day}, ${_endDate.year}'),
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
            'A countable end is a Payment plan.',
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

  static String _unitLabel(_Unit unit) => switch (unit) {
        _Unit.day => 'Day',
        _Unit.week => 'Week',
        _Unit.month => 'Month',
        _Unit.year => 'Year',
      };

  static String _unitPlural(_Unit unit) => switch (unit) {
        _Unit.day => 'day(s)',
        _Unit.week => 'week(s)',
        _Unit.month => 'month(s)',
        _Unit.year => 'year(s)',
      };

  static String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    return switch (n % 10) { 1 => '${n}st', 2 => '${n}nd', 3 => '${n}rd', _ => '${n}th' };
  }
}

const List<String> _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

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

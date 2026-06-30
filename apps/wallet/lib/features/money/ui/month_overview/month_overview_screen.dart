import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/calm_tokens.dart';
import '../../application/preferences_providers.dart';
import '../../domain/month_period.dart';
import '../add_entry/add_entry_sheet.dart';

/// Home — the current-period cockpit (Wallet ADR-0002; nav branch 0).
///
/// Body-only: [AppShell] supplies the Scaffold, app bar, and nav chrome.
///
/// For now this is an **honest empty cockpit**: a real current-period header
/// (derived from the user's month-start-day and today) plus an empty-state
/// invitation to add the first flow. The rich cockpit — on-track strip, budgets,
/// the Upcoming/Logged worklist, side panel — returns once Home is wired to the
/// real `MonthProjection` (Money ADR-0007); until then there is no read model to
/// render, so we show nothing fake. The add-expense sheet (the FAB) writes real
/// flows via the outbox.
class MonthOverviewScreen extends ConsumerWidget {
  const MonthOverviewScreen({super.key});

  static const double _wideBreakpoint = 900;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startDay = ref.watch(preferencesProvider).value?.monthStartDay ?? 1;
    final period = _Period.current(DateTime.now(), startDay);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _wideBreakpoint;
        final pad = EdgeInsets.fromLTRB(wide ? 28 : 18, 24, wide ? 28 : 18, 96);

        return Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: SingleChildScrollView(
                  padding: pad,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _PeriodHeader(period: period),
                      const SizedBox(height: 24),
                      _EmptyPeriod(monthLabel: period.monthLabel),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: wide ? 24 : 16,
              bottom: wide ? 24 : 16,
              child: _Fab(extended: wide),
            ),
          ],
        );
      },
    );
  }
}

class _PeriodHeader extends StatelessWidget {
  const _PeriodHeader({required this.period});

  final _Period period;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                period.monthLabel,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontFamily: CalmTokens.fontDisplay,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(period.span, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 7),
                decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
              ),
              Text(
                'Active',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: CalmTokens.of(theme.brightness).sageDeep,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyPeriod extends StatelessWidget {
  const _EmptyPeriod({required this.monthLabel});

  final String monthLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(CalmTokens.radiusLg),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.receipt_long_outlined, color: theme.colorScheme.primary, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            'Nothing logged yet',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Add an expense or income and it will show up here once $monthLabel is wired to your data.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: muted, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _Fab extends StatelessWidget {
  const _Fab({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final child = extended
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, color: theme.colorScheme.onSecondary),
                const SizedBox(width: 9),
                Text(
                  'Add expense',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontFamily: CalmTokens.fontDisplay,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSecondary,
                  ),
                ),
              ],
            ),
          )
        : Icon(Icons.add, color: theme.colorScheme.onSecondary);

    return Material(
      color: theme.colorScheme.secondary,
      shape: const StadiumBorder(),
      elevation: 6,
      shadowColor: theme.colorScheme.secondary.withValues(alpha: 0.5),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showAddEntry(context),
        child: SizedBox(
          height: extended ? 50 : 56,
          width: extended ? null : 56,
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// The current accounting period as the empty cockpit header needs it — label,
/// calendar span and day-in-period, derived from [containingPeriod] (ADR-0013).
class _Period {
  _Period({required this.monthLabel, required this.span});

  final String monthLabel;
  final String span;

  factory _Period.current(DateTime now, int startDay) {
    final p = containingPeriod(now, startDay);
    final start = _anchor(p.year, p.month, startDay);
    final next = p.month == 12 ? (year: p.year + 1, month: 1) : (year: p.year, month: p.month + 1);
    final endExclusive = _anchor(next.year, next.month, startDay);
    final lastDay = endExclusive.subtract(const Duration(days: 1));

    final today = DateTime(now.year, now.month, now.day);
    final dayOfPeriod = today.difference(start).inDays + 1;
    final totalDays = endExclusive.difference(start).inDays;

    final span = '${_short[start.month - 1]} ${start.day} – ${_short[lastDay.month - 1]} ${lastDay.day}'
        ' · day $dayOfPeriod of $totalDays';

    return _Period(monthLabel: '${_full[p.month - 1]} ${p.year}', span: span);
  }

  static DateTime _anchor(int year, int month, int startDay) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, startDay < daysInMonth ? startDay : daysInMonth);
  }

  static const List<String> _short = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const List<String> _full = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
}

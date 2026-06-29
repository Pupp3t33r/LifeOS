import 'package:flutter/material.dart';
import '../../../../app/theme/calm_tokens.dart';
import 'home_mock.dart';
import 'widgets/home_side_panel.dart';
import 'widgets/on_track_strip.dart';
import 'widgets/period_switcher.dart';
import 'widgets/worklist.dart';

/// Home — the **current-period cockpit** (Wallet ADR-0002; nav branch 0).
///
/// Body-only: [AppShell] supplies the Scaffold, app bar, and nav chrome. This
/// is the operating surface for the active month — switch periods, see the
/// on-track verdict, work the Upcoming/Logged worklist, and close. View
/// toggles (Status/Type, the budgets and per-row expands) are live; the actions
/// that change money state (mark paid/bought, add, close) are stubbed until the
/// Money backend (`MonthProjection`, ADR-0007) is wired.
///
/// NOTE: the screen renders [homeMock] — hand-authored sample data. See
/// `home_mock.dart`; delete it when the real projection lands.
class MonthOverviewScreen extends StatefulWidget {
  const MonthOverviewScreen({super.key});

  @override
  State<MonthOverviewScreen> createState() => _MonthOverviewScreenState();
}

/// How the worklist is grouped — by realized status, or by entry type.
enum _Grouping { status, type }

class _MonthOverviewScreenState extends State<MonthOverviewScreen> {
  _Grouping _grouping = _Grouping.status;
  bool _budgetsExpanded = false;

  /// Below this width the side rail is dropped and the layout goes single-column.
  static const double _twoColumnBreakpoint = 900;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _twoColumnBreakpoint;
        final pad = EdgeInsets.fromLTRB(wide ? 28 : 18, 22, wide ? 28 : 18, 96);

        final Widget body;
        if (wide) {
          body = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: pad,
                  child: _WorkColumn(
                    grouping: _grouping,
                    budgetsExpanded: _budgetsExpanded,
                    onGroupingChanged: (g) => setState(() => _grouping = g),
                    onToggleBudgets: () => setState(() => _budgetsExpanded = !_budgetsExpanded),
                    compact: false,
                  ),
                ),
              ),
              SizedBox(
                width: 300,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(0, 22, 28, 96),
                  child: HomeSidePanel(mock: homeMock),
                ),
              ),
            ],
          );
        } else {
          body = SingleChildScrollView(
            padding: pad,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _WorkColumn(
                  grouping: _grouping,
                  budgetsExpanded: _budgetsExpanded,
                  onGroupingChanged: (g) => setState(() => _grouping = g),
                  onToggleBudgets: () => setState(() => _budgetsExpanded = !_budgetsExpanded),
                  compact: true,
                ),
                const SizedBox(height: 24),
                CloseCard(
                  monthLabel: homeMock.summary.monthLabel,
                  daysLeft: homeMock.summary.daysLeft,
                ),
              ],
            ),
          );
        }

        return Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: body,
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

/// The work column — period switcher, on-track strip, the grouping toggle, and
/// the worklist sections. Shared by both layouts.
class _WorkColumn extends StatelessWidget {
  const _WorkColumn({
    required this.grouping,
    required this.budgetsExpanded,
    required this.onGroupingChanged,
    required this.onToggleBudgets,
    required this.compact,
  });

  final _Grouping grouping;
  final bool budgetsExpanded;
  final ValueChanged<_Grouping> onGroupingChanged;
  final VoidCallback onToggleBudgets;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PeriodSwitcher(summary: homeMock.summary, compact: compact),
        const SizedBox(height: 18),
        OnTrackStrip(
          summary: homeMock.summary,
          budgets: homeMock.budgets,
          expanded: budgetsExpanded,
          onToggle: onToggleBudgets,
          compact: compact,
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'This period',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            _GroupingToggle(value: grouping, onChanged: onGroupingChanged),
          ],
        ),
        const SizedBox(height: 14),
        ..._sections(compact),
      ],
    );
  }

  List<Widget> _sections(bool compact) {
    final entries = homeMock.entries;
    final sections = <Widget>[];

    void add(WorklistSection section) {
      if (sections.isNotEmpty) sections.add(const SizedBox(height: 20));
      sections.add(section);
    }

    if (grouping == _Grouping.status) {
      final upcoming = entries.where((x) => !x.logged).toList();
      final logged = entries.where((x) => x.logged).toList();
      add(WorklistSection(
        title: 'Upcoming',
        trailing: '${upcoming.length} to handle',
        actionLabel: 'Confirm all',
        entries: upcoming,
        compact: compact,
      ));
      add(WorklistSection(
        title: 'Logged',
        trailing: '${logged.length} flows',
        actionLabel: 'View in Activity',
        entries: logged,
        compact: compact,
        addLabel: compact ? 'Add to June' : 'Add an expense or income to June',
      ));
    } else {
      final byType = <EntryType, ({String title, List<HomeEntry> items})>{
        EntryType.recurring: (title: 'Recurring', items: []),
        EntryType.planned: (title: 'Planned', items: []),
        EntryType.adhoc: (title: 'Ad-hoc', items: []),
      };
      for (final e in entries) {
        byType[e.type]!.items.add(e);
      }
      final order = [EntryType.recurring, EntryType.planned, EntryType.adhoc];
      for (var i = 0; i < order.length; i++) {
        final group = byType[order[i]]!;
        if (group.items.isEmpty) continue;
        add(WorklistSection(
          title: group.title,
          trailing: '${group.items.length}',
          entries: group.items,
          compact: compact,
          addLabel: order[i] == EntryType.adhoc
              ? (compact ? 'Add to June' : 'Add an expense or income to June')
              : null,
        ));
      }
    }

    return sections;
  }
}

class _GroupingToggle extends StatelessWidget {
  const _GroupingToggle({required this.value, required this.onChanged});

  final _Grouping value;
  final ValueChanged<_Grouping> onChanged;

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
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(context, 'Status', _Grouping.status),
          _segment(context, 'Type', _Grouping.type),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, String label, _Grouping group) {
    final theme = Theme.of(context);
    final selected = value == group;
    return GestureDetector(
      onTap: () => onChanged(group),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
          boxShadow: selected
              ? [BoxShadow(color: theme.colorScheme.shadow.withValues(alpha: 0.08), blurRadius: 3, offset: const Offset(0, 1))]
              : null,
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: selected ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontWeight: FontWeight.w600,
          ),
        ),
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
        onTap: () {/* TODO: add an expense or income to the active period */},
        child: SizedBox(
          height: extended ? 50 : 56,
          width: extended ? null : 56,
          child: Center(child: child),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/calm_tokens.dart';
import '../../../../app/theme/category_colors.dart';
import '../../application/categories_providers.dart';
import '../../application/period_flows_providers.dart';
import '../../application/preferences_providers.dart';
import '../../application/recurring_providers.dart' hide PeriodKey;
import '../../application/selected_period_providers.dart';
import '../../domain/category.dart';
import '../../domain/money.dart';
import '../../domain/period_flows.dart';
import '../../domain/recurring/recurring_payment.dart';
import '../recurring/create_menu.dart';
import '../recurring/occurrence_actions.dart';
import '../recurring/plan_occurrence_sheet.dart';
import '../recurring/resolve_ongoing_sheet.dart';

/// Home — the current-period cockpit (Wallet ADR-0002; nav branch 0).
///
/// Body-only: [AppShell] supplies the Scaffold, app bar, and nav chrome.
///
/// Renders the period's flow ledger (Money ADR-0016) from the local read-through
/// cache — the logged worklist plus the per-currency net — and lets the FAB add
/// more via the outbox. Just-added (or offline) entries appear immediately as
/// optimistic, "syncing" rows. The richer cockpit (on-track strip, budgets,
/// upcoming) returns once the composed `MonthProjection` (ADR-0007) is built; until
/// then there is no projected/target/actual to show, so we show only what's real.
class MonthOverviewScreen extends ConsumerWidget {
  const MonthOverviewScreen({super.key});

  static const double _wideBreakpoint = 900;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startDay = ref.watch(preferencesProvider).value?.monthStartDay ?? 1;
    final key = ref.watch(viewedPeriodProvider);
    final status = ref.watch(viewedPeriodStatusProvider);
    final period = _Period.forKey(key, startDay, DateTime.now());

    final entries = ref.watch(periodFlowsProvider(key)).value ?? const <FlowEntry>[];
    final totals = ref.watch(periodTotalsProvider(key));
    final syncedAt = ref.watch(periodSyncedAtProvider(key)).value;

    // The in-flight portion of the net (ADR-0004 §5, "Option A"): the signed sum of
    // just the pending entries, per currency, zero-nets dropped. The headline net
    // already includes these; this is only the honest label of how much isn't synced.
    final pendingTotals = _sumByCurrency(entries.where((x) => x.pending))
        .where((x) => x.amount != 0)
        .toList();
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final nameById = {for (final c in categories) c.id: c.name};
    final upcoming = ref.watch(upcomingOccurrencesProvider(key));

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
                      _PeriodHeader(
                        period: period,
                        status: status,
                        totals: totals,
                        pendingTotals: pendingTotals,
                        syncedAt: syncedAt,
                        onPrevious: () =>
                            ref.read(selectedPeriodProvider.notifier).previous(),
                        onNext: () => ref.read(selectedPeriodProvider.notifier).next(),
                        onJumpToActive: () =>
                            ref.read(selectedPeriodProvider.notifier).jumpToActive(),
                      ),
                      const SizedBox(height: 24),
                      if (upcoming.isNotEmpty) ...[
                        _UpcomingList(
                          occurrences: upcoming,
                          nameById: nameById,
                          status: status,
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (entries.isNotEmpty)
                        _Worklist(entries: entries, nameById: nameById)
                      else if (upcoming.isEmpty)
                        _EmptyPeriod(monthLabel: period.monthLabel),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: wide ? 24 : 16,
              bottom: wide ? 24 : 16,
              child: _Fab(extended: wide, allowOneOff: status == PeriodStatus.active),
            ),
          ],
        );
      },
    );
  }
}

class _PeriodHeader extends StatelessWidget {
  const _PeriodHeader({
    required this.period,
    required this.status,
    required this.totals,
    required this.pendingTotals,
    required this.syncedAt,
    required this.onPrevious,
    required this.onNext,
    required this.onJumpToActive,
  });

  final _Period period;
  final PeriodStatus status;
  final List<Money> totals;
  final List<Money> pendingTotals;
  final DateTime? syncedAt;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onJumpToActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                period.monthLabel,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontFamily: CalmTokens.fontDisplay,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            _NavArrow(icon: Icons.chevron_left, tooltip: 'Previous period', onTap: onPrevious),
            _NavArrow(icon: Icons.chevron_right, tooltip: 'Next period', onTap: onNext),
            const Spacer(),
            if (status != PeriodStatus.active)
              _JumpToActiveButton(onTap: onJumpToActive)
            else
              _StatusBadge(status: status),
          ],
        ),
        if (status != PeriodStatus.active) ...[
          const SizedBox(height: 6),
          _StatusBadge(status: status),
        ],
        const SizedBox(height: 4),
        Text(period.span, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
        if (totals.isNotEmpty) ...[
          const SizedBox(height: 10),
          _NetTotals(totals: totals),
        ],
        if (pendingTotals.isNotEmpty) _PendingCaption(totals: pendingTotals),
        if (syncedAt != null) ...[
          const SizedBox(height: 6),
          Text(
            'Updated ${_relativeTime(syncedAt!, DateTime.now())}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ],
      ],
    );
  }
}

/// A period-step chevron (‹ / ›) for the switcher (ADR-0002).
class _NavArrow extends StatelessWidget {
  const _NavArrow({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      iconSize: 26,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
      icon: Icon(icon),
    );
  }
}

/// Snap-back-to-today pill, shown only while browsing a non-active period.
class _JumpToActiveButton extends StatelessWidget {
  const _JumpToActiveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primary.withValues(alpha: 0.10),
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.today_outlined, size: 15, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'Current',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The viewed period's status chip: Active (you're here), Planning (a future period —
/// preview only, ADR-0023), or Past.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final PeriodStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    final (label, dot, text) = switch (status) {
      PeriodStatus.active => ('Active', theme.colorScheme.primary, tokens.sageDeep),
      PeriodStatus.future => ('Planning', tokens.clay, tokens.clay),
      PeriodStatus.past => ('Past', tokens.line, theme.colorScheme.onSurface.withValues(alpha: 0.6)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: dot.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(right: 7),
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: text,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// The period's net result, one figure per currency (no FX conversion yet —
/// ADR-0007's display-currency rollup arrives with the projection).
class _NetTotals extends StatelessWidget {
  const _NetTotals({required this.totals});

  final List<Money> totals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final money in totals)
          RichText(
            text: TextSpan(
              style: theme.textTheme.titleMedium?.copyWith(
                fontFamily: CalmTokens.fontDisplay,
                fontWeight: FontWeight.w600,
                color: money.amount < 0 ? tokens.clay : tokens.sageDeep,
              ),
              children: [
                TextSpan(text: _signed(money.amount, money.currency)),
                TextSpan(
                  text: '  net',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The in-flight portion of the net, labelled honestly (ADR-0004 §5). The headline
/// already includes these amounts; this caption says how much of it isn't synced yet,
/// and self-erases the moment everything confirms. The accent colour marks it as
/// not-yet-applied; the ± sign in the text carries direction.
class _PendingCaption extends StatelessWidget {
  const _PendingCaption({required this.totals});

  final List<Money> totals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final amounts = totals.map((x) => _signed(x.amount, x.currency)).join(', ');
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_upload_outlined, size: 12, color: muted),
          const SizedBox(width: 5),
          Flexible(
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.labelSmall?.copyWith(color: muted),
                children: [
                  const TextSpan(text: 'includes '),
                  TextSpan(
                    text: amounts,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: tokens.clay,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(text: ' syncing'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Worklist extends StatelessWidget {
  const _Worklist({required this.entries, required this.nameById});

  final List<FlowEntry> entries;
  final Map<String, String> nameById;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'Logged · ${entries.length}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: muted,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border.all(color: theme.colorScheme.outline),
            borderRadius: BorderRadius.circular(CalmTokens.radiusLg),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                if (i > 0) Divider(height: 1, color: theme.colorScheme.outline),
                _EntryTile(entry: entries[i], nameById: nameById),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.nameById});

  final FlowEntry entry;
  final Map<String, String> nameById;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    final firstCategoryId = entry.lines
        .map((x) => x.categoryId)
        .firstWhere((x) => x != null, orElse: () => null);
    final dotColor = firstCategoryId != null
        ? CategoryPalette.forId(firstCategoryId).of(context)
        : tokens.line;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(right: 13, top: 2),
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title(entry, nameById),
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle(entry, nameById),
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _signed(entry.total.amount, entry.total.currency),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontFamily: CalmTokens.fontDisplay,
                  fontWeight: FontWeight.w600,
                  color: entry.isIncome ? tokens.sageDeep : theme.colorScheme.onSurface,
                ),
              ),
              if (entry.pending) ...[
                const SizedBox(height: 3),
                _SyncingPill(),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Best human title: the entry note, else a single line's note, else the
  /// category name, else the bare direction.
  String _title(FlowEntry entry, Map<String, String> nameById) {
    final note = entry.description?.trim();
    if (note != null && note.isNotEmpty) return note;
    if (entry.lines.length == 1) {
      final lineNote = entry.lines.first.description?.trim();
      if (lineNote != null && lineNote.isNotEmpty) return lineNote;
      final id = entry.lines.first.categoryId;
      if (id != null && nameById[id] != null) return nameById[id]!;
    }
    return entry.isIncome ? 'Income' : 'Expense';
  }

  String _subtitle(FlowEntry entry, Map<String, String> nameById) {
    final date = '${_shortMonths[entry.occurredAt.month - 1]} ${entry.occurredAt.day}';
    if (entry.lines.length > 1) return '$date · ${entry.lines.length} items';
    final id = entry.lines.first.categoryId;
    final name = id != null ? nameById[id] : null;
    return name != null ? '$date · $name' : date;
  }
}

class _SyncingPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.cloud_upload_outlined, size: 12, color: muted),
        const SizedBox(width: 4),
        Text('Syncing', style: theme.textTheme.labelSmall?.copyWith(color: muted)),
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
            'Add an expense or income for $monthLabel and it shows up here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: muted, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _Fab extends StatelessWidget {
  const _Fab({required this.extended, required this.allowOneOff});

  final bool extended;

  /// Whether the one-off "Add" verb is offered — only on the active period, since a
  /// one-off is always an actual that files into the current period (ADR-0023).
  final bool allowOneOff;

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
                  'Add',
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
        onTap: () => showCreateMenu(context, allowOneOff: allowOneOff),
        child: SizedBox(
          height: extended ? 50 : 56,
          width: extended ? null : 56,
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// The period's due-but-unresolved recurring occurrences (ADR-0017) — the "Upcoming"
/// worklist. Each is a projected occurrence with a one-tap Mark paid; tapping the row
/// body opens its resolve surface (an editable sheet for Ongoing, a read-only detail
/// for a Payment plan).
class _UpcomingList extends StatelessWidget {
  const _UpcomingList({
    required this.occurrences,
    required this.nameById,
    required this.status,
  });

  final List<PeriodOccurrence> occurrences;
  final Map<String, String> nameById;
  final PeriodStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    // A future period is planning-only (ADR-0023): its occurrences are a projection,
    // not yet payable, so the worklist reads as a preview with no resolve actions.
    final preview = status == PeriodStatus.future;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            '${preview ? 'Planned' : 'Upcoming'} · ${occurrences.length}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: muted,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border.all(color: theme.colorScheme.outline),
            borderRadius: BorderRadius.circular(CalmTokens.radiusLg),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < occurrences.length; i++) ...[
                if (i > 0) Divider(height: 1, color: theme.colorScheme.outline),
                _OccurrenceTile(
                  item: occurrences[i],
                  nameById: nameById,
                  preview: preview,
                ),
              ],
            ],
          ),
        ),
        if (preview)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 8),
            child: Text(
              'Preview — these become payable once the period begins.',
              style: theme.textTheme.labelSmall?.copyWith(color: muted),
            ),
          ),
      ],
    );
  }
}

class _OccurrenceTile extends ConsumerWidget {
  const _OccurrenceTile({required this.item, required this.nameById, this.preview = false});

  final PeriodOccurrence item;
  final Map<String, String> nameById;

  /// In a future ("Planning") period the occurrence is a projection only — no resolve
  /// sheet, no Mark paid (ADR-0023). The row renders as a static preview line.
  final bool preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final recurring = item.recurring;
    final occ = item.occurrence;

    final firstCategoryId =
        occ.lines.map((x) => x.categoryId).firstWhere((x) => x != null, orElse: () => null);
    final dotColor =
        firstCategoryId != null ? CategoryPalette.forId(firstCategoryId).of(context) : tokens.line;
    final currency = occ.expectedAmount.currency;
    final categoryName = occ.lines.length == 1 && firstCategoryId != null ? nameById[firstCategoryId] : null;
    final due = 'due ${_shortMonths[occ.dueDate.month - 1]} ${occ.dueDate.day}';

    Future<void> markPaid() async {
      await markOccurrencePaidAsPlanned(
          ref, recurringId: recurring.id, occurrence: occ, description: recurring.name);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked paid')));
      }
    }

    void openDetail() {
      if (recurring.mode == ScheduleMode.materialized) {
        showPlanOccurrence(context, recurring, occ);
      } else {
        showResolveOngoing(context, recurring, occ);
      }
    }

    return InkWell(
      onTap: preview ? null : openDetail,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 13),
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recurring.name,
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    categoryName != null ? '$due · $categoryName' : due,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _signed(occ.expectedAmount.amount, currency),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontFamily: CalmTokens.fontDisplay,
                fontWeight: FontWeight.w600,
                color: recurring.isIncome ? tokens.sageDeep : theme.colorScheme.onSurface,
              ),
            ),
            if (!preview) ...[
              const SizedBox(width: 10),
              Material(
                color: tokens.sage.withValues(alpha: 0.06),
                shape: StadiumBorder(side: BorderSide(color: tokens.sage)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: markPaid,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      'Mark paid',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: tokens.sageDeep,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The viewed accounting period as the cockpit header needs it — its display label
/// and calendar span, anchored on the user's month-start-day (ADR-0013).
class _Period {
  _Period({required this.monthLabel, required this.span});

  final String monthLabel;
  final String span;

  /// Header label + calendar span for [key] under [startDay]. The "day X of Y"
  /// progress suffix is added only when [key] is the period containing [now] — for
  /// any other browsed period it would be meaningless, so the span is just the range.
  factory _Period.forKey(PeriodKey key, int startDay, DateTime now) {
    final start = _anchor(key.year, key.month, startDay);
    final next = key.month == 12 ? (year: key.year + 1, month: 1) : (year: key.year, month: key.month + 1);
    final endExclusive = _anchor(next.year, next.month, startDay);
    final lastDay = endExclusive.subtract(const Duration(days: 1));

    final today = DateTime(now.year, now.month, now.day);
    final isActive = !today.isBefore(start) && today.isBefore(endExclusive);

    final range = '${_shortMonths[start.month - 1]} ${start.day} – '
        '${_shortMonths[lastDay.month - 1]} ${lastDay.day}';
    final span = isActive
        ? '$range · day ${today.difference(start).inDays + 1} of ${endExclusive.difference(start).inDays}'
        : range;

    return _Period(
      monthLabel: '${_fullMonths[key.month - 1]} ${key.year}',
      span: span,
    );
  }

  static DateTime _anchor(int year, int month, int startDay) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, startDay < daysInMonth ? startDay : daysInMonth);
  }
}

const List<String> _shortMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const List<String> _fullMonths = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// Compact currency formatting for display only (the decimal-safe model lands with
/// the OpenAPI client in Phase 5). [_signed] prefixes the sign by the amount's sign.
const Map<String, String> _symbols = {
  'USD': '\$', 'CAD': '\$', 'EUR': '€', 'GBP': '£', 'JPY': '¥',
};

String _money(num amount, String currency) {
  final decimals = currency == 'JPY' ? 0 : 2;
  final magnitude = amount.abs().toStringAsFixed(decimals);
  final symbol = _symbols[currency];
  return symbol != null ? '$symbol$magnitude' : '$magnitude $currency';
}

String _signed(num amount, String currency) {
  final sign = amount < 0 ? '−' : '+';
  return '$sign${_money(amount, currency)}';
}

/// Signed net per currency over [entries] (currencies sorted). Used for the pending
/// caption; the headline net is the same fold over the full merged list
/// (`periodTotalsProvider`).
List<Money> _sumByCurrency(Iterable<FlowEntry> entries) {
  final byCurrency = <String, num>{};
  for (final entry in entries) {
    byCurrency.update(
      entry.total.currency,
      (sum) => sum + entry.total.amount,
      ifAbsent: () => entry.total.amount,
    );
  }
  final currencies = byCurrency.keys.toList()..sort();
  return [for (final c in currencies) Money(amount: byCurrency[c]!, currency: c)];
}

/// Coarse relative time for the cache freshness line. Computed at build (it doesn't
/// tick on its own), but the cockpit revalidates on every open and outbox change, so
/// in practice it re-renders fresh; precision finer than this isn't worth a timer.
String _relativeTime(DateTime then, DateTime now) {
  final diff = now.difference(then);
  if (diff.inSeconds < 45) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return 'on ${_shortMonths[then.month - 1]} ${then.day}';
}

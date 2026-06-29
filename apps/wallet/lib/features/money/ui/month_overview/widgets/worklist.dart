import 'package:flutter/material.dart';
import '../../../../../app/theme/calm_tokens.dart';
import '../../../../../app/theme/category_colors.dart';
import '../home_mock.dart';

/// One worklist group — a header (title · count, with a section action) and a
/// card of container rows. Grouping (Status / Type) is decided by the caller;
/// this just renders the entries it's handed (Wallet ADR-0002).
class WorklistSection extends StatelessWidget {
  const WorklistSection({
    super.key,
    required this.title,
    required this.trailing,
    required this.entries,
    this.actionLabel,
    this.compact = false,
    this.addLabel,
  });

  final String title;
  final String trailing; // "5 to handle", "6 flows"
  final List<HomeEntry> entries;
  final String? actionLabel; // "Confirm all", "View in Activity"
  final bool compact;

  /// When set, an "add a flow" row is appended inside the card.
  final String? addLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    final rows = <Widget>[];
    for (var i = 0; i < entries.length; i++) {
      if (i > 0) rows.add(Divider(height: 1, color: theme.colorScheme.outline));
      rows.add(WorklistRow(entry: entries[i], compact: compact));
    }
    if (addLabel != null) {
      if (rows.isNotEmpty) rows.add(Divider(height: 1, color: theme.colorScheme.outline));
      rows.add(_AddRow(label: addLabel!));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text: '  ·  $trailing',
                        style: theme.textTheme.bodySmall?.copyWith(color: muted),
                      ),
                    ],
                  ),
                ),
              ),
              if (actionLabel != null)
                InkWell(
                  onTap: () {/* TODO: section action — Confirm all / View in Activity */},
                  borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      actionLabel!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: CalmTokens.of(theme.brightness).sageDeep,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border.all(color: theme.colorScheme.outline),
            borderRadius: BorderRadius.circular(CalmTokens.radiusMd),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(CalmTokens.radiusMd),
            child: Column(children: rows),
          ),
        ),
      ],
    );
  }
}

/// A single container row — `icon · name · [proportion bar + count] · amount`
/// (Wallet ADR-0002/0003). Multi-line entries get a chevron and expand to their
/// per-line breakdown; single-line entries show the category name and don't
/// expand. The leading control and trailing action are presentational — marking
/// paid/bought is not wired yet.
class WorklistRow extends StatefulWidget {
  const WorklistRow({super.key, required this.entry, this.compact = false});

  final HomeEntry entry;
  final bool compact;

  @override
  State<WorklistRow> createState() => _WorklistRowState();
}

class _WorklistRowState extends State<WorklistRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = widget.entry;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    // Distinct categories, in first-appearance order, for the subtitle text.
    final categories = <String, HomeCategoryRef>{};
    for (final line in entry.lines) {
      categories.putIfAbsent(line.category.name, () => line.category);
    }
    final lineCount = entry.lines.length;
    final expandable = lineCount > 1;

    final String base;
    if (lineCount == 1) {
      base = categories.values.first.name;
    } else if (categories.length == 1) {
      base = '$lineCount items · ${categories.values.first.name}';
    } else {
      base = '$lineCount items';
    }
    final subtitle = entry.note == null ? base : '$base · ${entry.note}';

    // Trailing: upcoming rows on a phone show the action only (the amount is
    // implied); elsewhere show the amount, plus the action when not yet logged.
    final showAction = !entry.logged;
    final showAmount = !(widget.compact && !entry.logged);

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Leading(entry: entry),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.title,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface),
                      ),
                    ),
                    if (entry.due != null) ...[
                      const SizedBox(width: 7),
                      Text(
                        entry.due!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (expandable) ...[
                      const SizedBox(width: 6),
                      Icon(
                        _open ? Icons.expand_less : Icons.expand_more,
                        size: 15,
                        color: muted,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _ProportionBar(lines: entry.lines),
                    const SizedBox(width: 9),
                    Flexible(
                      child: Text(
                        subtitle,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: muted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (showAmount) ...[
            const SizedBox(width: 12),
            Text(
              formatSigned(entry.total),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: CalmTokens.fontDisplay,
                fontWeight: FontWeight.w600,
                color: entry.isIncome ? CalmTokens.of(theme.brightness).sageDeep : theme.colorScheme.secondary,
              ),
            ),
          ],
          if (showAction) ...[
            const SizedBox(width: 12),
            _ActionChip(entry: entry, compact: widget.compact),
          ],
        ],
      ),
    );

    return Column(
      children: [
        if (expandable)
          InkWell(onTap: () => setState(() => _open = !_open), child: row)
        else
          row,
        if (expandable && _open) _Lines(lines: entry.lines),
      ],
    );
  }
}

class _Leading extends StatelessWidget {
  const _Leading({required this.entry});

  final HomeEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (entry.logged) {
      return _circle(
        fill: theme.colorScheme.primary,
        border: theme.colorScheme.primary,
        child: Icon(Icons.check, size: 13, color: theme.colorScheme.onPrimary),
      );
    }
    if (entry.type == EntryType.planned) {
      return _circle(
        border: theme.colorScheme.secondary,
        child: Icon(Icons.shopping_bag_outlined, size: 13, color: theme.colorScheme.secondary),
      );
    }
    return _circle(border: theme.colorScheme.onSurface.withValues(alpha: 0.25));
  }

  Widget _circle({Color? fill, required Color border, Widget? child}) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 1.8),
      ),
      child: child,
    );
  }
}

/// The category proportion bar — one solid segment per category, sized by its
/// share of the entry's total. Single category → one solid bar.
class _ProportionBar extends StatelessWidget {
  const _ProportionBar({required this.lines});

  final List<HomeLine> lines;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    // Sum magnitudes per category, preserving first-appearance order.
    final sums = <CategoryPalette, double>{};
    for (final line in lines) {
      sums.update(line.category.color, (v) => v + line.amount.abs(),
          ifAbsent: () => line.amount.abs());
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
      child: SizedBox(
        width: 84,
        height: 5,
        child: Row(
          children: [
            for (final entry in sums.entries)
              Expanded(
                flex: (entry.value * 1000).round().clamp(1, 1 << 30),
                child: ColoredBox(color: entry.key.resolve(brightness)),
              ),
          ],
        ),
      ),
    );
  }
}

class _Lines extends StatelessWidget {
  const _Lines({required this.lines});

  final List<HomeLine> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return Container(
      width: double.infinity,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.025),
      child: Column(
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.fromLTRB(51, 8, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: line.category.color.of(context), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      line.name,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface),
                    ),
                  ),
                  Text(line.category.name, style: theme.textTheme.labelSmall?.copyWith(color: muted)),
                  const SizedBox(width: 12),
                  Text(
                    formatSigned(line.amount),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: CalmTokens.fontDisplay,
                      fontWeight: FontWeight.w600,
                      color: muted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.entry, required this.compact});

  final HomeEntry entry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buy = entry.type == EntryType.planned;
    final color = buy ? theme.colorScheme.secondary : theme.colorScheme.primary;
    final label = compact ? (buy ? 'Buy' : 'Pay') : (buy ? 'Mark bought' : 'Mark paid');

    return Material(
      color: color.withValues(alpha: 0.06),
      shape: StadiumBorder(side: BorderSide(color: color)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {/* TODO: mark paid / mark bought — record the flow */},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _AddRow extends StatelessWidget {
  const _AddRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primary.withValues(alpha: 0.05),
      child: InkWell(
        onTap: () {/* TODO: add an expense or income to this period */},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.colorScheme.primary, width: 1.5),
                ),
                child: Icon(Icons.add, size: 14, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: CalmTokens.of(theme.brightness).sageDeep,
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

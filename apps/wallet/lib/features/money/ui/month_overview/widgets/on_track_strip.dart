import 'package:flutter/material.dart';
import '../../../../../app/theme/calm_tokens.dart';
import '../home_mock.dart';

/// The reactive verdict strip — "on track by", a projected-vs-target bar — with
/// the period budgets folded into a `details` expand (Money ADR-0025). Stats are
/// demoted to this strip; Home's job is operating the month, not reading it
/// (Wallet ADR-0002).
class OnTrackStrip extends StatelessWidget {
  const OnTrackStrip({
    super.key,
    required this.summary,
    required this.budgets,
    required this.expanded,
    required this.onToggle,
    this.compact = false,
  });

  final HomeSummary summary;
  final List<HomeBudget> budgets;
  final bool expanded;
  final VoidCallback onToggle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final ahead = summary.onTrackBy >= 0;

    final verdict = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          ahead ? 'On track by' : 'Behind by',
          style: theme.textTheme.labelSmall?.copyWith(
            color: muted,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          formatSigned(summary.onTrackBy),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontFamily: CalmTokens.fontDisplay,
            fontWeight: FontWeight.w700,
            color: ahead ? theme.colorScheme.primary : theme.colorScheme.secondary,
          ),
        ),
      ],
    );

    final barAndLegend = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TrackBar(projected: summary.projected, target: summary.target),
        const SizedBox(height: 9),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _legend(theme, muted, 'projected', formatUsd(summary.projected)),
            _legend(theme, muted, 'target', formatUsd(summary.target)),
          ],
        ),
      ],
    );

    final toggle = _DetailsToggle(expanded: expanded, onTap: onToggle);

    // Phone: verdict + details on one line, the bar stacked full-width below.
    // Wide: a single line with the bar flexing in the middle.
    final Widget content = compact
        ? Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [verdict, toggle],
              ),
              const SizedBox(height: 12),
              barAndLegend,
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              verdict,
              const SizedBox(width: 22),
              Expanded(child: barAndLegend),
              const SizedBox(width: 18),
              toggle,
            ],
          );

    final strip = Container(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: expanded
            ? const BorderRadius.vertical(top: Radius.circular(CalmTokens.radiusMd))
            : BorderRadius.circular(CalmTokens.radiusMd),
      ),
      child: content,
    );

    if (!expanded) return strip;

    return Column(
      children: [
        strip,
        _Budgets(budgets: budgets),
      ],
    );
  }

  Widget _legend(ThemeData theme, Color muted, String label, String value) {
    return Text.rich(
      TextSpan(
        style: theme.textTheme.bodySmall?.copyWith(color: muted),
        children: [
          TextSpan(text: '$label '),
          TextSpan(
            text: value,
            style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// The projected-vs-target bar: a solid fill to the target mark, a lighter
/// surplus beyond it, and a tick at the target.
class _TrackBar extends StatelessWidget {
  const _TrackBar({required this.projected, required this.target});

  final double projected;
  final double target;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = projected >= target ? projected : target;
    final targetFrac = scale <= 0 ? 0.0 : (target / scale).clamp(0.0, 1.0);
    final projFrac = scale <= 0 ? 0.0 : (projected / scale).clamp(0.0, 1.0);
    final solidFrac = projected >= target ? targetFrac : projFrac;
    final surplusFrac = projected > target ? (projFrac - targetFrac) : 0.0;

    return SizedBox(
      height: 9,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
            child: Container(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
              child: Row(
                children: [
                  Expanded(
                    flex: (solidFrac * 1000).round(),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [theme.colorScheme.primary, CalmTokens.of(theme.brightness).sageDeep],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: (surplusFrac * 1000).round(),
                    child: ColoredBox(color: theme.colorScheme.primary.withValues(alpha: 0.4)),
                  ),
                  Expanded(flex: ((1 - solidFrac - surplusFrac) * 1000).round(), child: const SizedBox()),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment(targetFrac * 2 - 1, 0),
            child: Container(width: 2, color: theme.colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}

class _DetailsToggle extends StatelessWidget {
  const _DetailsToggle({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'details',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: CalmTokens.of(theme.brightness).sageDeep,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 18,
              color: CalmTokens.of(theme.brightness).sageDeep,
            ),
          ],
        ),
      ),
    );
  }
}

class _Budgets extends StatelessWidget {
  const _Budgets({required this.budgets});

  final List<HomeBudget> budgets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(CalmTokens.radiusMd)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: theme.colorScheme.outline)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'BUDGETS THIS PERIOD',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: muted,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Manage',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: CalmTokens.of(theme.brightness).sageDeep,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          for (final b in budgets) _BudgetRow(budget: b),
        ],
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({required this.budget});

  final HomeBudget budget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final color = budget.color.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 108,
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    budget.name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
              child: Container(
                height: 8,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.07),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: budget.fraction,
                  child: ColoredBox(color: color),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 96,
            child: Text.rich(
              textAlign: TextAlign.right,
              TextSpan(
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: CalmTokens.fontDisplay,
                  color: muted,
                ),
                children: [
                  TextSpan(
                    text: formatUsd(budget.spent),
                    style: TextStyle(
                      color: budget.full ? theme.colorScheme.secondary : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(text: ' / ${formatPlain(budget.limit)}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

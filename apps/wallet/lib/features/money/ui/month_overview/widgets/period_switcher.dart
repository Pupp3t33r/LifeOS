import 'package:flutter/material.dart';
import '../../../../../app/theme/calm_tokens.dart';
import '../home_mock.dart';

/// The period header — month title, span, prev/next arrows, and the
/// active/other-open-period badges (Money ADR-0023). The arrows and badges are
/// presentational here; switching periods is wired when the backend can serve
/// more than one [MonthProjection].
class PeriodSwitcher extends StatelessWidget {
  const PeriodSwitcher({super.key, required this.summary, this.compact = false});

  final HomeSummary summary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    final monthInfo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          summary.monthLabel,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontFamily: CalmTokens.fontDisplay,
            fontWeight: FontWeight.w600,
            fontSize: compact ? 21 : 25,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          summary.periodSpan,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
      ],
    );

    // In compact mode the title sits in a width-bounded column, so the month
    // info can flex/ellipsize. In wide mode it sits inside another Row (loose
    // width), where Expanded would have no bound — keep it intrinsic there.
    final title = Row(
      mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
      children: [
        _Arrow(icon: Icons.chevron_left, onTap: () {/* TODO: previous period */}),
        const SizedBox(width: 12),
        if (compact) Expanded(child: monthInfo) else monthInfo,
        const SizedBox(width: 12),
        _Arrow(icon: Icons.chevron_right, onTap: () {/* TODO: next period */}),
      ],
    );

    final badges = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (summary.active) const _ActiveBadge(),
        if (!compact && summary.nextPeriodLabel != null) ...[
          const SizedBox(width: 8),
          _GhostBadge(label: '${summary.nextPeriodLabel} ›'),
        ],
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 12),
          badges,
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [title, badges],
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: CircleBorder(side: BorderSide(color: theme.colorScheme.outline)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(width: 34, height: 34, child: Icon(icon, size: 18, color: theme.colorScheme.onSurface)),
      ),
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
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
            decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            'Active',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GhostBadge extends StatelessWidget {
  const _GhostBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../../app/theme/calm_tokens.dart';
import '../home_mock.dart';

/// The desktop side rail — accounts, pinned rates, and the close-period card.
/// On phones the rail is dropped (accounts live in their own destination); only
/// [CloseCard] is carried over, below the worklist.
class HomeSidePanel extends StatelessWidget {
  const HomeSidePanel({super.key, required this.mock});

  final HomeMock mock;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AccountsCard(accounts: mock.accounts),
        const SizedBox(height: 16),
        RatesCard(rates: mock.rates, source: mock.rateSource),
        const SizedBox(height: 16),
        CloseCard(monthLabel: mock.summary.monthLabel, daysLeft: mock.summary.daysLeft),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.action, required this.children});

  final String title;
  final String? action;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Container(
      padding: const EdgeInsets.fromLTRB(17, 16, 17, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(CalmTokens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: muted,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (action != null)
                Text(
                  action!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: CalmTokens.of(theme.brightness).sageDeep,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class AccountsCard extends StatelessWidget {
  const AccountsCard({super.key, required this.accounts});

  final List<HomeAccount> accounts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return _Card(
      title: 'Accounts',
      action: 'Manage',
      children: [
        for (final a in accounts)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: a.accent ? theme.colorScheme.secondary : theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    a.name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface),
                  ),
                ),
                Text(
                  a.value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: CalmTokens.fontDisplay,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (a.secondary != null) ...[
                  const SizedBox(width: 6),
                  Text(a.secondary!, style: theme.textTheme.labelSmall?.copyWith(color: muted)),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class RatesCard extends StatelessWidget {
  const RatesCard({super.key, required this.rates, required this.source});

  final List<HomeRate> rates;
  final String source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final sageDeep = CalmTokens.of(theme.brightness).sageDeep;
    return _Card(
      title: 'Rates · pinned',
      action: 'Open rates ›',
      children: [
        for (final r in rates)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    r.pair,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface),
                  ),
                ),
                Text(
                  r.value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: CalmTokens.fontDisplay,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 34,
                  child: Text(
                    '${r.up ? '▲' : '▼'} ${r.delta}',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: r.up ? sageDeep : theme.colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 9),
        Row(
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(source, style: theme.textTheme.labelSmall?.copyWith(color: muted)),
          ],
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () {/* TODO: pin a currency */},
          child: Text(
            '+ Pin a currency',
            style: theme.textTheme.bodySmall?.copyWith(color: sageDeep, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// The close-period prompt (Money ADR-0021). Carried to phones below the
/// worklist; on desktop it sits at the foot of the side rail.
class CloseCard extends StatelessWidget {
  const CloseCard({super.key, required this.monthLabel, required this.daysLeft});

  final String monthLabel;
  final int daysLeft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    final onFill = theme.colorScheme.onPrimary;
    final month = monthLabel.split(' ').first;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [theme.colorScheme.primary, tokens.sageDeep],
        ),
        borderRadius: BorderRadius.circular(CalmTokens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$month ends in $daysLeft days',
            style: theme.textTheme.titleSmall?.copyWith(
              fontFamily: CalmTokens.fontDisplay,
              fontWeight: FontWeight.w600,
              color: onFill,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            "When you're done, close the month to bank your savings and settle anything unpaid.",
            style: theme.textTheme.bodySmall?.copyWith(color: onFill.withValues(alpha: 0.82)),
          ),
          const SizedBox(height: 13),
          Material(
            color: theme.colorScheme.surface,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {/* TODO: close the period */},
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Text(
                  'Close $month →',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.sageDeep,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

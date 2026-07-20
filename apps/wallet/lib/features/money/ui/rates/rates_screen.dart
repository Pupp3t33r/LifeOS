import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/calm_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/fx_rates_providers.dart';
import '../../domain/fx_rate.dart';

/// Settings → Exchange rates (Money ADR-0015). A low-prominence, read-only view
/// of the FX rates behind every conversion in the app: for each currency pair it
/// shows the applicable rate, its source (Belarusbank / Frankfurter), the as-of
/// date, and a staleness badge when the rate is older than the freshness
/// threshold. Satisfies the no-false-precision principle — every converted number
/// is traceable to a dated, sourced rate.
///
/// A leaf above the shell, reached from a navigation row on Settings.
class RatesScreen extends ConsumerWidget {
  const RatesScreen({super.key});

  static const double _contentMaxWidth = 640;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final rates = ref.watch(latestFxRatesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.ratesScreenTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.ratesRefreshTooltip,
            onPressed: () => ref.invalidate(latestFxRatesProvider),
          ),
        ],
      ),
      body: SafeArea(
        child: rates.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              _ErrorState(onRetry: () => ref.invalidate(latestFxRatesProvider)),
          data: (list) => _RatesList(rates: list),
        ),
      ),
    );
  }
}

class _RatesList extends StatelessWidget {
  const _RatesList({required this.rates});

  final List<FxRate> rates;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (rates.isEmpty) {
      return _EmptyState(message: l10n.ratesEmpty);
    }

    final now = DateTime.now();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 48),
      children: [
        for (final rate in rates)
          Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: RatesScreen._contentMaxWidth),
              child: _RateRow(rate: rate, now: now),
            ),
          ),
      ],
    );
  }
}

class _RateRow extends StatelessWidget {
  const _RateRow({required this.rate, required this.now});

  final FxRate rate;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final stale = rate.isStaleAsOf(now);

    final rateText = NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: 4,
    ).format(rate.rate);
    final asOfText = l10n.ratesAsOf(DateFormat.yMMMd(locale).format(rate.asOf));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(CalmTokens.radiusMd),
        border: Border.all(color: tokens.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${rate.base} → ${rate.quote}',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '1 ${rate.base} = $rateText ${rate.quote}',
                  style: theme.textTheme.bodyMedium?.copyWith(color: tokens.muted),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      _sourceLabel(l10n, rate.source),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: tokens.muted),
                    ),
                    Text(
                      '  ·  $asOfText',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: tokens.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (stale) ...[
            const SizedBox(width: 12),
            _StaleBadge(label: l10n.ratesStaleBadge, tokens: tokens),
          ],
        ],
      ),
    );
  }

  static String _sourceLabel(AppLocalizations l10n, FxRateSource source) =>
      switch (source) {
        FxRateSource.belarusbank => l10n.ratesSourceBelarusbank,
        FxRateSource.frankfurter => l10n.ratesSourceFrankfurter,
        FxRateSource.identity => l10n.ratesSourceIdentity,
        FxRateSource.unknown => l10n.ratesSourceUnknown,
      };
}

class _StaleBadge extends StatelessWidget {
  const _StaleBadge({required this.label, required this.tokens});

  final String label;
  final CalmTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.clay.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: tokens.clay, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: tokens.muted),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.ratesLoadError,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: tokens.muted),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: Text(l10n.ratesRetryButton)),
          ],
        ),
      ),
    );
  }
}

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
/// A currency-filter chip strip narrows the list to every pair containing a chosen
/// currency (base or quote) — a pure client-side view control over the
/// already-fetched pairs. Pinning a pair and adding an untracked currency are v2
/// (see docs/design/rates/).
///
/// A leaf above the shell, reached from a navigation row on Settings.
class RatesScreen extends ConsumerStatefulWidget {
  const RatesScreen({super.key});

  @override
  ConsumerState<RatesScreen> createState() => _RatesScreenState();
}

class _RatesScreenState extends ConsumerState<RatesScreen> {
  /// The currency the list is filtered to, or null for "All".
  String? _filter;

  @override
  Widget build(BuildContext context) {
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
          data: _buildData,
        ),
      ),
    );
  }

  Widget _buildData(List<FxRate> all) {
    if (all.isEmpty) {
      return _EmptyState(message: AppLocalizations.of(context).ratesEmpty);
    }

    // Every currency that appears in a pair, as base or quote.
    final currencies = <String>{};
    for (final rate in all) {
      currencies
        ..add(rate.base)
        ..add(rate.quote);
    }
    final sorted = currencies.toList()..sort();

    // Fall back to "All" if a previously-picked currency is no longer present
    // (e.g. after a refresh dropped it) — without mutating state during build.
    final active = _filter != null && currencies.contains(_filter) ? _filter : null;
    final filtered = active == null
        ? all
        : [for (final rate in all) if (rate.base == active || rate.quote == active) rate];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FilterStrip(
          currencies: sorted,
          selected: active,
          onSelect: (currency) => setState(() => _filter = currency),
        ),
        Expanded(child: _RatesList(rates: filtered)),
      ],
    );
  }
}

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({
    required this.currencies,
    required this.selected,
    required this.onSelect,
  });

  final List<String> currencies;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
      child: Row(
        children: [
          _FilterChip(
            label: l10n.ratesFilterAll,
            active: selected == null,
            onTap: () => onSelect(null),
          ),
          for (final currency in currencies) ...[
            const SizedBox(width: 8),
            _FilterChip(
              label: currency,
              active: selected == currency,
              onTap: () => onSelect(currency),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? tokens.sage : tokens.surface,
            borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
            border: Border.all(color: active ? tokens.sage : tokens.line),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: active ? CalmTokens.white : tokens.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _RatesList extends StatelessWidget {
  const _RatesList({required this.rates});

  final List<FxRate> rates;

  static const double _contentMaxWidth = 640;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 48),
      children: [
        for (final rate in rates)
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
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

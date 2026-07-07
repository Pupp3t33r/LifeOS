import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/locale/locale_controller.dart';
import '../../../../app/theme/calm_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/wordmark.dart';
import '../../../security/application/security_providers.dart';
import '../../domain/currencies.dart';
import 'onboarding_controller.dart';
import 'onboarding_state.dart';

/// Currency codes offered at onboarding. The chosen one opens the first account
/// and defaults the display currency (ADR-0013). The shared pool; display labels are
/// localized where a string exists, otherwise the shared English name — see [_currencyLabel].
const List<String> _currencyCodes = kCurrencyPool;

/// The `name — code` label for a currency code — localized for the original set,
/// else the shared English name (e.g. "Belarusian Ruble — BYN").
String _currencyLabel(AppLocalizations l10n, String code) => switch (code) {
      'USD' => l10n.currencyUsd,
      'EUR' => l10n.currencyEur,
      'GBP' => l10n.currencyGbp,
      'PLN' => l10n.currencyPln,
      'JPY' => l10n.currencyJpy,
      'CAD' => l10n.currencyCad,
      _ => '${kCurrencyNames[code] ?? code} — $code',
    };

/// First-run onboarding — "Set up your first month" (Money ADR-0013). Collects
/// the first savings account and the month start day, the minimum server-owned
/// config the app needs. A single centred question column, comfortably width-capped
/// on wide screens; the whole flow scrolls on short viewports.
///
/// The AppBar carries a language switcher (Wallet's first localized surface, see
/// `apps/wallet/docs/adr/0001-app-localization.md`) so the whole flow can be read
/// in the user's language from the very first screen.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  static const double _wideBreakpoint = 900;
  static const double _maxWidth = 1180;
  static const double _formMaxWidth = 520;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);
    // Hidden entirely on web and on devices without biometrics → 2-step flow there.
    final biometricsSupported =
        ref.watch(biometricSupportedProvider).maybeWhen(data: (v) => v, orElse: () => false);

    final ask = _Ask(state: state, biometricsSupported: biometricsSupported);

    return Scaffold(
      appBar: AppBar(
        title: const Wordmark(),
        titleSpacing: 24,
        actions: const [_LanguageSwitcher(), SizedBox(width: 8)],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= _wideBreakpoint;
                return SingleChildScrollView(
                  padding: wide
                      ? const EdgeInsets.fromLTRB(40, 24, 40, 40)
                      : const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: _formMaxWidth),
                      child: ask,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Always-visible language switcher (AppBar), mirroring the Keycloak login-page
/// switcher for visual/behavioral consistency. Applies the choice live — the
/// whole flow re-renders immediately — and persists it device-locally.
class _LanguageSwitcher extends ConsumerWidget {
  const _LanguageSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final active = Localizations.localeOf(context).languageCode;
    return PopupMenuButton<String>(
      tooltip: l10n.languageSwitcherTooltip,
      icon: const Icon(Icons.language_outlined),
      onSelected: (code) =>
          ref.read(localeControllerProvider.notifier).setLocale(Locale(code)),
      itemBuilder: (context) => [
        CheckedPopupMenuItem(
          value: 'en',
          checked: active == 'en',
          child: Text(l10n.languageNameEnglish),
        ),
        CheckedPopupMenuItem(
          value: 'ru',
          checked: active == 'ru',
          child: Text(l10n.languageNameRussian),
        ),
      ],
    );
  }
}

/// The left/bottom column: progress, the active step, and the action row.
class _Ask extends ConsumerWidget {
  const _Ask({required this.state, required this.biometricsSupported});

  final OnboardingState state;
  final bool biometricsSupported;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Progress(step: state.step, total: biometricsSupported ? 3 : 2),
        const SizedBox(height: 26),
        switch (state.step) {
          0 => _AccountStep(state: state),
          1 => _MonthStep(state: state),
          _ => _BiometricStep(state: state),
        },
        if (state.error != null) ...[
          const SizedBox(height: 16),
          _ErrorBanner(message: state.error!),
        ],
        const SizedBox(height: 28),
        _Actions(state: state, biometricsSupported: biometricsSupported),
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: i <= step ? theme.colorScheme.primary : theme.colorScheme.outline,
                borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
              ),
            ),
          ),
          if (i < total - 1) const SizedBox(width: 7),
        ],
      ],
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.eyebrow, required this.title, required this.lede});

  final String eyebrow;
  final String title;
  final String lede;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.secondary,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontFamily: CalmTokens.fontDisplay,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          lede,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.66),
          ),
        ),
        const SizedBox(height: 26),
      ],
    );
  }
}

class _AccountStep extends ConsumerWidget {
  const _AccountStep({required this.state});

  final OnboardingState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(onboardingControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeader(
          eyebrow: l10n.onbAccountEyebrow,
          title: l10n.onbAccountTitle,
          lede: l10n.onbAccountLede,
        ),
        _Field(
          label: l10n.onbAccountNameLabel,
          child: TextFormField(
            initialValue: state.accountName,
            onChanged: controller.setAccountName,
            decoration: InputDecoration(hintText: l10n.onbAccountNameHint),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 13,
              child: _Field(
                label: l10n.onbCurrencyLabel,
                child: DropdownButtonFormField<String>(
                  initialValue: state.currency,
                  items: [
                    for (final code in _currencyCodes)
                      DropdownMenuItem(value: code, child: Text(_currencyLabel(l10n, code))),
                  ],
                  onChanged: (value) {
                    if (value != null) controller.setCurrency(value);
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 10,
              child: _Field(
                label: l10n.onbOpeningBalanceLabel,
                child: TextFormField(
                  initialValue: state.openingBalance,
                  onChanged: controller.setOpeningBalance,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(hintText: l10n.onbOpeningBalanceHint),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _Hint(l10n.onbAccountHint),
      ],
    );
  }
}

class _MonthStep extends ConsumerWidget {
  const _MonthStep({required this.state});

  final OnboardingState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(onboardingControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeader(
          eyebrow: l10n.onbMonthEyebrow,
          title: l10n.onbMonthTitle,
          lede: l10n.onbMonthLede,
        ),
        _ChoiceCard(
          title: l10n.onbCalendarMonthTitle,
          subtitle: l10n.onbCalendarMonthSubtitle,
          selected: !state.useCustomMonth,
          onTap: controller.useCalendarMonth,
        ),
        const SizedBox(height: 12),
        _ChoiceCard(
          title: l10n.onbCustomDayTitle,
          subtitle: l10n.onbCustomDaySubtitle,
          selected: state.useCustomMonth,
          onTap: controller.useCustomMonth,
        ),
        if (state.useCustomMonth) ...[
          const SizedBox(height: 16),
          _DayPicker(day: state.day, onChanged: controller.setDay),
        ],
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_clock_outlined, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                l10n.onbMonthLockNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Optional final step — only reached on devices that support biometrics (so it
/// never appears on web). Toggles the device-local app-lock (ADR-0014).
class _BiometricStep extends ConsumerWidget {
  const _BiometricStep({required this.state});

  final OnboardingState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(onboardingControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeader(
          eyebrow: l10n.onbBiometricEyebrow,
          title: l10n.onbBiometricTitle,
          lede: l10n.onbBiometricLede,
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(CalmTokens.radiusMd),
            border: Border.all(color: theme.colorScheme.outline, width: 1.5),
          ),
          child: SwitchListTile(
            value: state.appLockEnabled,
            onChanged: controller.setAppLockEnabled,
            title: Text(
              l10n.onbBiometricSwitchTitle,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              l10n.onbBiometricSwitchSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CalmTokens.radiusMd),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _Hint(l10n.onbBiometricHint),
      ],
    );
  }
}

class _DayPicker extends StatelessWidget {
  const _DayPicker({required this.day, required this.onChanged});

  final int day;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    // English uses an ordinal suffix on the number ("25th"); other locales just
    // show the number — the localized "day of the month" label carries the rest.
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';
    final dayText = isEnglish ? '$day${_ordinal(day)}' : '$day';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CalmTokens.radiusMd),
        border: Border.all(
          color: theme.colorScheme.outline,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                dayText,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontFamily: CalmTokens.fontDisplay,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.onbDayOfMonth,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          Slider(
            value: day.toDouble(),
            min: 1,
            max: 31,
            divisions: 30,
            label: '$day',
            onChanged: (value) => onChanged(value.round()),
          ),
          if (day > 28)
            Text(
              l10n.onbDayClampNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
        ],
      ),
    );
  }

  static String _ordinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return 'th';
    return switch (n % 10) {
      1 => 'st',
      2 => 'nd',
      3 => 'rd',
      _ => 'th',
    };
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(CalmTokens.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.08)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(CalmTokens.radiusMd),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : theme.colorScheme.outline,
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(top: 2, right: 13),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? theme.colorScheme.primary : theme.colorScheme.outline,
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.state, required this.biometricsSupported});

  final OnboardingState state;
  final bool biometricsSupported;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final busy = state.submitting;
    // Last step is the month step (1) unless the device adds the biometric step (2).
    final isLastStep = state.step == (biometricsSupported ? 2 : 1);

    return Row(
      children: [
        if (state.step > 0)
          TextButton(
            onPressed: busy ? null : controller.back,
            child: Text(l10n.onbBack),
          ),
        const Spacer(),
        Expanded(
          flex: 2,
          child: FilledButton(
            onPressed: busy
                ? null
                : () {
                    if (isLastStep) {
                      controller.submit(l10n.onbError);
                    } else {
                      controller.next();
                    }
                  },
            child: busy
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Text(isLastStep ? l10n.onbFinish : l10n.onbContinue),
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(CalmTokens.radiusMd),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

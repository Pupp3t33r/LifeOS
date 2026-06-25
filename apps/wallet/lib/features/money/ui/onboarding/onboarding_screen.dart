import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/calm_tokens.dart';
import '../../../security/application/security_providers.dart';
import 'onboarding_canvas.dart';
import 'onboarding_controller.dart';
import 'onboarding_state.dart';

/// Currencies offered at onboarding. The chosen one opens the first account and
/// defaults the display currency (ADR-0013).
const List<({String code, String label})> _currencies = [
  (code: 'USD', label: 'US Dollar — USD'),
  (code: 'EUR', label: 'Euro — EUR'),
  (code: 'GBP', label: 'Pound Sterling — GBP'),
  (code: 'PLN', label: 'Polish Złoty — PLN'),
  (code: 'JPY', label: 'Japanese Yen — JPY'),
  (code: 'CAD', label: 'Canadian Dollar — CAD'),
];

/// First-run onboarding — "Set up your first month" (Money ADR-0013). Collects
/// the first savings account and the month start day, the minimum server-owned
/// config the savings canvas needs. Responsive: a two-column layout (question +
/// living canvas) on wide screens, stacked (canvas on top) on phones.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  static const double _wideBreakpoint = 900;
  static const double _maxWidth = 1180;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);
    // Hidden entirely on web and on devices without biometrics → 2-step flow there.
    final biometricsSupported =
        ref.watch(biometricSupportedProvider).maybeWhen(data: (v) => v, orElse: () => false);

    final canvas = OnboardingCanvas(
      accountName: state.accountName,
      currency: state.currency,
      monthStartDay: state.effectiveMonthStartDay,
    );
    final ask = _Ask(state: state, biometricsSupported: biometricsSupported);

    return Scaffold(
      appBar: AppBar(
        title: const _Wordmark(),
        titleSpacing: 24,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= _wideBreakpoint;
                if (wide) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(40, 24, 40, 40),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 92, child: ask),
                        const SizedBox(width: 48),
                        Expanded(flex: 108, child: canvas),
                      ],
                    ),
                  );
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      canvas,
                      const SizedBox(height: 28),
                      ask,
                    ],
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

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RichText(
      text: TextSpan(
        style: theme.textTheme.titleLarge?.copyWith(
          fontFamily: CalmTokens.fontDisplay,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface,
        ),
        children: [
          const TextSpan(text: 'wallet'),
          TextSpan(text: '.', style: TextStyle(color: theme.colorScheme.primary)),
        ],
      ),
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
    final controller = ref.read(onboardingControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepHeader(
          eyebrow: 'where savings land',
          title: 'Where do your savings live?',
          lede: "Add one savings account to start. The money you don't spend each "
              "month settles here — it's the only thing Wallet needs to begin.",
        ),
        _Field(
          label: 'Account name',
          child: TextFormField(
            initialValue: state.accountName,
            onChanged: controller.setAccountName,
            decoration: const InputDecoration(hintText: 'Main savings'),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 13,
              child: _Field(
                label: 'Currency',
                child: DropdownButtonFormField<String>(
                  initialValue: state.currency,
                  items: [
                    for (final c in _currencies)
                      DropdownMenuItem(value: c.code, child: Text(c.label)),
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
                label: 'In it today',
                child: TextFormField(
                  initialValue: state.openingBalance,
                  onChanged: controller.setOpeningBalance,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(hintText: '0'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _Hint("A rough number is fine — you can adjust it anytime. Wallet never "
            "guesses what it can't see."),
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
    final controller = ref.read(onboardingControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepHeader(
          eyebrow: 'your month',
          title: 'When does your month start?',
          lede: "Most people plan by the calendar month. If you're paid on a "
              "certain day, start there instead — your month runs from that day "
              "to the next.",
        ),
        _ChoiceCard(
          title: 'Calendar month',
          subtitle: 'Runs the 1st to the last day',
          selected: !state.useCustomMonth,
          onTap: controller.useCalendarMonth,
        ),
        const SizedBox(height: 12),
        _ChoiceCard(
          title: 'A day I choose',
          subtitle: 'For payday- or rent-day planning',
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
                "You can change this until you close your first month. After that "
                "it's locked, so your history can't shift underneath you.",
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
    final controller = ref.read(onboardingControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepHeader(
          eyebrow: 'protect your wallet',
          title: 'Lock Wallet when you open it?',
          lede: "Use your fingerprint or face to unlock Wallet each time — your "
              "money stays private even if your device is left unlocked. You can "
              "change this later in settings.",
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
              'Unlock with biometrics',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Recommended for a money app',
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
        _Hint("Uses the fingerprint or face already set up on this device — "
            "nothing to enroll here."),
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
                '$day${_ordinal(day)}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontFamily: CalmTokens.fontDisplay,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'day of the month',
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
              'Shorter months clamp to their last day — February would start on '
              'the 28th.',
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
    final controller = ref.read(onboardingControllerProvider.notifier);
    final busy = state.submitting;
    // Last step is the month step (1) unless the device adds the biometric step (2).
    final isLastStep = state.step == (biometricsSupported ? 2 : 1);

    return Row(
      children: [
        if (state.step > 0)
          TextButton(
            onPressed: busy ? null : controller.back,
            child: const Text('Back'),
          ),
        const Spacer(),
        Expanded(
          flex: 2,
          child: FilledButton(
            onPressed: busy
                ? null
                : () {
                    if (isLastStep) {
                      controller.submit();
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
                : Text(isLastStep ? 'Finish setup' : 'Continue'),
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

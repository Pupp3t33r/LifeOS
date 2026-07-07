import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/calm_tokens.dart';

/// Expense ↔ Income segmented toggle shared by the create sheets. Income flips the
/// sign and the accent to sage.
class DirectionToggle extends StatelessWidget {
  const DirectionToggle({super.key, required this.isIncome, required this.onChanged});

  final bool isIncome;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget segment(String label, bool income) {
      final selected = income == isIncome;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
          onTap: () => onChanged(income),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? theme.colorScheme.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
              boxShadow: selected
                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.09), blurRadius: 3, offset: const Offset(0, 1))]
                  : null,
            ),
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: selected
                    ? (income
                        ? CalmTokens.of(theme.brightness).sageDeep
                        : theme.colorScheme.onSurface)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
      ),
      child: Row(children: [segment('Expense', false), segment('Income', true)]),
    );
  }
}

/// The amount input: a signed hero (or inline) numeric field with a tappable currency
/// chip. Sign and accent follow [isIncome].
class MoneyAmountField extends StatelessWidget {
  const MoneyAmountField({
    super.key,
    required this.controller,
    required this.isIncome,
    required this.currency,
    required this.onCurrencyTap,
    this.big = true,
  });

  final TextEditingController controller;
  final bool isIncome;
  final String currency;
  final VoidCallback onCurrencyTap;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    final accent = isIncome ? tokens.sageDeep : tokens.clay;
    final valueStyle = (big ? theme.textTheme.headlineMedium : theme.textTheme.titleLarge)?.copyWith(
      fontFamily: CalmTokens.fontDisplay,
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurface,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: tokens.sage),
        borderRadius: BorderRadius.circular(CalmTokens.radiusMd),
      ),
      child: Row(
        children: [
          Text(isIncome ? '+' : '−', style: valueStyle?.copyWith(color: accent)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              style: valueStyle,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: '0.00',
                hintStyle: valueStyle?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
            onTap: onCurrencyTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(currency, style: theme.textTheme.labelLarge),
                  const Icon(Icons.arrow_drop_down, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single-line text field styled like the sheet's other fields. [onChanged] lets a
/// composer rebuild on each keystroke (e.g. to re-evaluate a save button's enabled state).
class SheetTextField extends StatelessWidget {
  const SheetTextField({super.key, required this.controller, required this.hint, this.onChanged});

  final TextEditingController controller;
  final String hint;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      onChanged: onChanged == null ? null : (_) => onChanged!(),
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(CalmTokens.radiusSm)),
      ),
    );
  }
}

/// A tappable row that shows a label + current value (with an optional colour dot) and
/// opens a picker — used for category and currency.
class PickerButton extends StatelessWidget {
  const PickerButton({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.dotColor,
    this.muted = false,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final Color? dotColor;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(CalmTokens.radiusSm),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(CalmTokens.radiusSm),
        ),
        child: Row(
          children: [
            if (dotColor != null) ...[
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 9),
            ],
            Expanded(
              child: Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: muted
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}

/// The sheet's primary action. Disabled state is a muted fill.
class PrimarySaveButton extends StatelessWidget {
  const PrimarySaveButton({
    super.key,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.loading = false,
    this.trailing,
  });

  final String label;
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: enabled ? tokens.sageDeep : theme.colorScheme.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(CalmTokens.radiusMd),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled && !loading ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: loading
                ? const Center(
                    child: SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: enabled ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (trailing != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          trailing!,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontFamily: CalmTokens.fontDisplay,
                            color: enabled ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

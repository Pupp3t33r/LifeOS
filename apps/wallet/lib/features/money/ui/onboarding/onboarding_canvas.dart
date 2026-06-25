import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../app/theme/calm_tokens.dart';

/// The "living canvas" — a preview of the savings canvas that updates as the
/// user answers onboarding. It shows **honest empty states** (nothing is faked):
/// projected figures read "after setup", savings "needs income & bills", target
/// "not set yet". Its one live element is the period header, which rewrites as
/// the month start day changes (e.g. "Jun 25 – Jul 24").
class OnboardingCanvas extends StatelessWidget {
  const OnboardingCanvas({
    super.key,
    required this.accountName,
    required this.currency,
    required this.monthStartDay,
  });

  final String accountName;
  final String currency;

  /// 1 = calendar month; otherwise the chosen start day.
  final int monthStartDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.62);
    final now = DateTime.now();
    final name = accountName.trim().isEmpty ? 'Main savings' : accountName.trim();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(CalmTokens.radiusLg),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'YOUR CANVAS · PREVIEW',
            style: theme.textTheme.labelSmall?.copyWith(
              color: muted,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  '${_monthName(now.month)} ${now.year}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontFamily: CalmTokens.fontDisplay,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _Pill(text: _spanLabel(now, monthStartDay)),
            ],
          ),
          const SizedBox(height: 14),
          _AccountChip(name: name, currency: currency),
          const SizedBox(height: 22),
          _LedgerLine(label: 'Projected income', value: 'after setup', pending: true),
          _divider(theme),
          _LedgerLine(label: 'Projected spending', value: 'after setup', pending: true),
          const SizedBox(height: 10),
          Divider(color: theme.colorScheme.outline, height: 1),
          const SizedBox(height: 10),
          _LedgerLine(
            label: 'Projected savings',
            value: 'needs income & bills',
            pending: true,
            emphasizeLabel: true,
          ),
          _divider(theme),
          _LedgerLine(
            label: 'Your target',
            value: 'not set yet',
            valueColor: theme.colorScheme.secondary,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  "We'll fill the blanks once you add what comes in and goes out.",
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider(ThemeData theme) => Divider(color: theme.colorScheme.outline, height: 1);

  /// Period span label, start-anchored with last-day clamping (mirrors the
  /// server's MonthPeriod and the prototype): calendar months read "Jun 1 – Jun
  /// 30"; a start day reads "Jun 25 – Jul 24".
  static String _spanLabel(DateTime now, int monthStartDay) {
    final y = now.year;
    final m = now.month;
    if (monthStartDay <= 1) {
      return '${_mon(m)} 1 – ${_mon(m)} ${_daysInMonth(y, m)}';
    }
    final start = min(monthStartDay, _daysInMonth(y, m));
    final nextYear = m == 12 ? y + 1 : y;
    final nextMonth = m == 12 ? 1 : m + 1;
    final endDay = min(monthStartDay, _daysInMonth(nextYear, nextMonth)) - 1;
    if (endDay >= 1) {
      return '${_mon(m)} $start – ${_mon(nextMonth)} $endDay';
    }
    return '${_mon(m)} $start – ${_mon(m)} ${_daysInMonth(y, m)}';
  }

  static int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  static const List<String> _shortMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const List<String> _fullMonths = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static String _mon(int m) => _shortMonths[m - 1];
  static String _monthName(int m) => _fullMonths[m - 1];
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          fontFamily: CalmTokens.fontDisplay,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _AccountChip extends StatelessWidget {
  const _AccountChip({required this.name, required this.currency});

  final String name;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          Text(name, style: theme.textTheme.bodySmall),
          Text(
            '  ·  $currency',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerLine extends StatelessWidget {
  const _LedgerLine({
    required this.label,
    required this.value,
    this.pending = false,
    this.emphasizeLabel = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool pending;
  final bool emphasizeLabel;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: pending ? muted : null,
                fontWeight: emphasizeLabel ? FontWeight.w600 : null,
              ),
            ),
          ),
          Text(
            value,
            style: pending
                ? theme.textTheme.bodySmall?.copyWith(
                    color: muted,
                    fontStyle: FontStyle.italic,
                  )
                : theme.textTheme.titleSmall?.copyWith(
                    fontFamily: CalmTokens.fontDisplay,
                    fontWeight: FontWeight.w600,
                    color: valueColor,
                  ),
          ),
        ],
      ),
    );
  }
}

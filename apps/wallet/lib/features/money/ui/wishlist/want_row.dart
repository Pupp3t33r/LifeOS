import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/calm_tokens.dart';
import '../../../../app/theme/category_colors.dart';
import '../../application/categories_providers.dart';
import '../../application/preferences_providers.dart';
import '../../application/wishlist_providers.dart';
import '../../domain/category.dart';
import '../../domain/money.dart';
import '../../domain/unit_system.dart';
import '../../domain/wishlist_item.dart';
import '../recurring/recurring_shared.dart' show formatMagnitude;
import 'schedule_chip_strip.dart';

/// One want in the wishlist list (Money ADR-0022/0034/0036, Variant B). Every row
/// wears a coloured **stage dot** + its **schedule as month chips** — one chip
/// language for One-time and Repeat. Tap opens the detail/edit sheet.
///
/// Stage: hollow = Wishing (idle), clay = Planned, denim = Paying off (financed),
/// sage = Bought (hidden in the collapsed row, so active rows are idle/planned/
/// financed). Schedule chips are fetched per-item from the read-composition
/// endpoint (ADR-0034 §"Board horizon") only for non-idle wants.
class WantRow extends ConsumerWidget {
  const WantRow({super.key, required this.want, required this.onTap});

  final WishlistItem want;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    final wide = MediaQuery.sizeOf(context).width >= 700;
    final isRepeat = want.recurrence == WishlistRecurrence.reusable;

    final catColor = want.categoryId == null
        ? null
        : CategoryColors.slotFor(want.categoryId!).resolve(theme.brightness);
    final estimate = want.estimate;

    return InkWell(
      borderRadius: BorderRadius.circular(CalmTokens.radiusMd),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(CalmTokens.radiusMd),
          border: Border(
            left: isRepeat
                ? BorderSide(color: tokens.sage.withValues(alpha: 0.5), width: 3)
                : BorderSide(color: tokens.line),
            top: BorderSide(color: tokens.line),
            right: BorderSide(color: tokens.line),
            bottom: BorderSide(color: tokens.line),
          ),
        ),
        child: Row(
          children: [
            _Glyph(categoryColor: catColor, isRepeat: isRepeat),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _titleRow(theme, tokens, isRepeat),
                  const SizedBox(height: 5),
                  _metaLine(context, ref, theme, tokens, wide),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _Estimate(estimate: estimate),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: tokens.muted.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _titleRow(ThemeData theme, CalmTokens tokens, bool isRepeat) {
    return Row(
      children: [
        Flexible(
          child: Text(
            want.name ?? 'Want',
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        _RecurrenceTag(isRepeat: isRepeat, tokens: tokens),
      ],
    );
  }

  Widget _metaLine(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    CalmTokens tokens,
    bool wide,
  ) {
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final categoryNames = {for (final c in categories) c.id: c.name};
    final children = <Widget>[
      _StageDot(status: want.status, tokens: tokens),
      const SizedBox(width: 7),
      if (want.categoryId != null)
        _CategoryLabel(
          name: categoryNames[want.categoryId] ?? '—',
          color: CategoryColors.slotFor(want.categoryId!).resolve(theme.brightness),
          theme: theme,
        )
      else
        Text(want._stageLabel,
            style: theme.textTheme.labelSmall?.copyWith(color: tokens.muted)),
    ];

    // Schedule: chips for planned wants, "Paying off" for financed, ghost for idle.
    if (want.status == WishlistCommitment.planned) {
      final chipsAsync = ref.watch(wishlistScheduleProvider(want.id));
      final system = ref.watch(preferencesProvider).value?.unitSystem ?? UnitSystem.metric;
      final chips = chipsAsync.value ?? const [];
      if (chips.isNotEmpty) {
        children
          ..add(const SizedBox(width: 8))
          ..add(ScheduleChipStrip(chips: chips, system: system, dense: !wide));
      }
    } else if (want.status == WishlistCommitment.financed) {
      children
        ..add(const SizedBox(width: 7))
        ..add(Text('Paying off',
            style: theme.textTheme.labelSmall?.copyWith(
                color: CategoryPalette.denim.resolve(theme.brightness),
                fontWeight: FontWeight.w600)));
    } else if (want.status == WishlistCommitment.idle) {
      children
        ..add(const SizedBox(width: 7))
        ..add(Text(want.recurrence == WishlistRecurrence.reusable ? 'plan any month' : 'plan on a month',
            style: theme.textTheme.labelSmall?.copyWith(color: tokens.muted)));
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 0,
      runSpacing: 4,
      children: children,
    );
  }
}

extension on WishlistItem {
  String get _stageLabel => switch (status) {
        WishlistCommitment.idle => 'Wishing',
        WishlistCommitment.planned => 'Planned',
        WishlistCommitment.financed => 'Paying off',
        WishlistCommitment.bought => 'Bought',
      };
}

class _Glyph extends StatelessWidget {
  const _Glyph({required this.categoryColor, required this.isRepeat});

  final Color? categoryColor;
  final bool isRepeat;

  @override
  Widget build(BuildContext context) {
    final tokens = CalmTokens.of(Theme.of(context).brightness);
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: categoryColor ?? tokens.muted.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(
        isRepeat ? Icons.repeat : Icons.shopping_bag_outlined,
        size: 15,
        color: Colors.white,
      ),
    );
  }
}

class _RecurrenceTag extends StatelessWidget {
  const _RecurrenceTag({required this.isRepeat, required this.tokens});

  final bool isRepeat;
  final CalmTokens tokens;

  @override
  Widget build(BuildContext context) {
    if (!isRepeat) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
        ),
        child: Text('One-time',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: tokens.muted,
                )),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: tokens.sage.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.repeat, size: 9, color: tokens.sageDeep),
          const SizedBox(width: 3),
          Text('Repeat',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: tokens.sageDeep,
                  )),
        ],
      ),
    );
  }
}

class _StageDot extends StatelessWidget {
  const _StageDot({required this.status, required this.tokens});

  final WishlistCommitment status;
  final CalmTokens tokens;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = switch (status) {
      WishlistCommitment.idle => null,
      WishlistCommitment.planned => tokens.clay,
      WishlistCommitment.financed => CategoryPalette.denim.resolve(brightness),
      WishlistCommitment.bought => tokens.sage,
    };
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: color == null ? Border.all(color: tokens.line, width: 1.6) : null,
      ),
    );
  }
}

class _CategoryLabel extends StatelessWidget {
  const _CategoryLabel({required this.name, required this.color, required this.theme});

  final String name;
  final Color color;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(name, style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor)),
      ],
    );
  }
}

class _Estimate extends StatelessWidget {
  const _Estimate({required this.estimate});

  final Money? estimate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    if (estimate == null) {
      return Text('—',
          style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted));
    }
    return Text(
      '−${formatMagnitude(estimate!.amount, estimate!.currency)}',
      style: theme.textTheme.titleSmall?.copyWith(
        fontFamily: CalmTokens.fontDisplay,
        fontWeight: FontWeight.w600,
        color: tokens.clay,
      ),
    );
  }
}

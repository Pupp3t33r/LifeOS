import 'package:flutter/material.dart';
import '../../../../app/theme/calm_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../add_entry/add_entry_sheet.dart';
import 'create_ongoing_sheet.dart';
import 'create_payment_plan_sheet.dart';
import 'create_planned_purchase_sheet.dart';

/// The FAB's create menu: four separate verbs (design/recurring) — **Add** (a
/// one-off expense/income), **Planned purchase** (an intention to buy this month,
/// ADR-0018), **Ongoing** (a Live recurring), **Payment plan** (a Materialized plan).
/// No chooser umbrella; each opens its own dedicated sheet.
///
/// [allowOneOff] gates the one-off **Add**: a one-off is always a *actual* dated
/// today-or-earlier (ADR-0016) and so lands in the active period regardless of what
/// the user is browsing. While the cockpit shows a non-active period, Add is disabled
/// so an actual can't be filed somewhere the user isn't looking (ADR-0023); the
/// period-agnostic recurring verbs stay available.
///
/// [allowPlanned] gates **Planned purchase**: planning is within-month and files onto
/// the viewed period ([plannedYear]/[plannedMonth]) — allowed on the active period and
/// on a future (Planning) one, disabled on a past period (ADR-0023).
Future<void> showCreateMenu(
  BuildContext context, {
  bool allowOneOff = true,
  bool allowPlanned = true,
  required int plannedYear,
  required int plannedMonth,
}) async {
  final choice = await showModalBottomSheet<_Create>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(CalmTokens.radiusLg)),
    ),
    builder: (context) {
      final tokens = CalmTokens.of(Theme.of(context).brightness);
      final l10n = AppLocalizations.of(context);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            _MenuItem(
              icon: Icons.add,
              color: tokens.sageDeep,
              title: l10n.createMenuAddTitle,
              subtitle: allowOneOff
                  ? l10n.createMenuAddSubtitleOn
                  : l10n.createMenuAddSubtitleOff,
              enabled: allowOneOff,
              onTap: allowOneOff ? () => Navigator.of(context).pop(_Create.add) : null,
            ),
            _MenuItem(
              icon: Icons.shopping_bag_outlined,
              color: tokens.clay,
              title: l10n.createMenuPlannedTitle,
              subtitle: allowPlanned
                  ? l10n.createMenuPlannedSubtitleOn
                  : l10n.createMenuPlannedSubtitleOff,
              enabled: allowPlanned,
              onTap: allowPlanned
                  ? () => Navigator.of(context).pop(_Create.plannedPurchase)
                  : null,
            ),
            _MenuItem(
              icon: Icons.autorenew,
              color: tokens.sageDeep,
              title: l10n.createMenuOngoingTitle,
              subtitle: l10n.createMenuOngoingSubtitle,
              onTap: () => Navigator.of(context).pop(_Create.ongoing),
            ),
            _MenuItem(
              icon: Icons.receipt_long_outlined,
              color: tokens.clay,
              title: l10n.createMenuPlanTitle,
              subtitle: l10n.createMenuPlanSubtitle,
              onTap: () => Navigator.of(context).pop(_Create.paymentPlan),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );

  if (!context.mounted || choice == null) return;
  switch (choice) {
    case _Create.add:
      await showAddEntry(context);
    case _Create.plannedPurchase:
      await showCreatePlannedPurchase(context, year: plannedYear, month: plannedMonth);
    case _Create.ongoing:
      await showCreateOngoing(context);
    case _Create.paymentPlan:
      await showCreatePaymentPlan(context);
  }
}

enum _Create { add, plannedPurchase, ongoing, paymentPlan }

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = enabled ? color : theme.colorScheme.onSurface.withValues(alpha: 0.35);
    return ListTile(
      enabled: enabled,
      leading: Container(
        width: 40, height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: tint.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: Icon(icon, color: tint, size: 20),
      ),
      title: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
      )),
      onTap: onTap,
    );
  }
}

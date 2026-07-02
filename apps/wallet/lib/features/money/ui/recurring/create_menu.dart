import 'package:flutter/material.dart';
import '../../../../app/theme/calm_tokens.dart';
import '../add_entry/add_entry_sheet.dart';
import 'create_ongoing_sheet.dart';
import 'create_payment_plan_sheet.dart';

/// The FAB's create menu: three separate verbs (design/recurring) — **Add** (a
/// one-off expense/income), **Ongoing** (a Live recurring), **Payment plan** (a
/// Materialized plan). No chooser umbrella; each opens its own dedicated sheet.
Future<void> showCreateMenu(BuildContext context) async {
  final choice = await showModalBottomSheet<_Create>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(CalmTokens.radiusLg)),
    ),
    builder: (context) {
      final tokens = CalmTokens.of(Theme.of(context).brightness);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            _MenuItem(
              icon: Icons.add,
              color: tokens.sageDeep,
              title: 'Add',
              subtitle: 'A one-off expense or income',
              onTap: () => Navigator.of(context).pop(_Create.add),
            ),
            _MenuItem(
              icon: Icons.autorenew,
              color: tokens.sageDeep,
              title: 'Ongoing',
              subtitle: 'Repeats until you stop it — rent, salary, a subscription',
              onTap: () => Navigator.of(context).pop(_Create.ongoing),
            ),
            _MenuItem(
              icon: Icons.receipt_long_outlined,
              color: tokens.clay,
              title: 'Payment plan',
              subtitle: 'One purchase, paid over a set of payments',
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
    case _Create.ongoing:
      await showCreateOngoing(context);
    case _Create.paymentPlan:
      await showCreatePaymentPlan(context);
  }
}

enum _Create { add, ongoing, paymentPlan }

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Container(
        width: 40, height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
      )),
      onTap: onTap,
    );
  }
}

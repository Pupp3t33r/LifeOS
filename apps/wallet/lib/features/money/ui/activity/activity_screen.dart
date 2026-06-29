import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/placeholder_page.dart';

/// Activity — the flows / transactions log (nav branch 2): line-itemed actuals,
/// add / edit / revert, filter by category. See apps/wallet/PLAN.md §13. Stub
/// for now.
class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PlaceholderPage(icon: Icons.receipt_long_outlined, title: l10n.navActivity);
  }
}

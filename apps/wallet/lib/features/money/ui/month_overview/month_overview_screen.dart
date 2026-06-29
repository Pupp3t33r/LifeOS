import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/placeholder_page.dart';

/// Home — the monthly **savings canvas** (Phase 1 primary surface; nav branch 0).
///
/// Body-only: the [AppShell] supplies the Scaffold, app bar, and navigation
/// chrome. The real canvas (target / projected / actual savings, planned
/// purchases, recurring checklist, recent activity) is built once the Money
/// backend exposes `MonthProjection`. See apps/wallet/PLAN.md §4 and §13.
class MonthOverviewScreen extends StatelessWidget {
  const MonthOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PlaceholderPage(icon: Icons.savings_outlined, title: l10n.navHome);
  }
}

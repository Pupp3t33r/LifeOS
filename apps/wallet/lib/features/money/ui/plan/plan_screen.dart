import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/placeholder_page.dart';

/// Plan — the projection levers (nav branch 1): recurring payments, wishlist /
/// planned purchases, and budgets. Whether this stays one page (sections/tabs)
/// or splits into separate destinations is an open IA thread — see
/// apps/wallet/PLAN.md §13. Stub for now.
class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PlaceholderPage(icon: Icons.event_note_outlined, title: l10n.navPlan);
  }
}

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/placeholder_page.dart';

/// Settings — secondary surface reached from the shell's gear button, not a
/// primary nav destination (see apps/wallet/PLAN.md §13). Full-screen with its
/// own app bar / back affordance since it sits above the shell. Will host:
/// language, theme, app-lock, passkey enrollment, display currency, month-start,
/// and category management (Money ADR-0024). Stub for now.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: PlaceholderPage(icon: Icons.settings_outlined, title: l10n.navSettings),
    );
  }
}

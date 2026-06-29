import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/placeholder_page.dart';

/// Accounts — savings accounts and balances (nav branch 3): create / rename /
/// archive, transfers (deferred, Money ADR-0009). See apps/wallet/PLAN.md §13.
/// Stub for now.
class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PlaceholderPage(icon: Icons.account_balance_wallet_outlined, title: l10n.navAccounts);
  }
}

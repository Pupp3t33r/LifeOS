import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/wordmark.dart';

/// The authenticated app shell — persistent navigation chrome around the primary
/// destinations (Home / Plan / Activity / Accounts). Adapts to width: a bottom
/// [NavigationBar] on narrow (phone-portrait) layouts, a [NavigationRail] on
/// wider ones, extended to a labelled sidebar on the widest (desktop/web
/// landscape). Settings is reached via the app-bar gear, not a nav slot.
///
/// This is the visible expression of the IA in apps/wallet/PLAN.md §13; the exact
/// destination set and breakpoints are still tentative. The shell owns the
/// Scaffold and app bar, so branch screens return body content only.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  /// Drives the indexed-stack branches; preserves each branch's state and scroll
  /// position across navigation.
  final StatefulNavigationShell navigationShell;

  /// Below this width: bottom navigation bar. At or above: navigation rail.
  static const double _railBreakpoint = 720;

  /// At or above this width: the rail extends to a labelled sidebar.
  static const double _extendedRailBreakpoint = 1240;

  void _goToBranch(int index) {
    // Tapping the active destination again resets it to its initial route.
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final destinations = _destinations(l10n);

    final appBar = AppBar(
      title: const Wordmark(),
      titleSpacing: 24,
      actions: [
        IconButton(
          tooltip: l10n.navSettings,
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => context.push('/settings'),
        ),
        const SizedBox(width: 8),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= _railBreakpoint;
        if (!useRail) {
          return Scaffold(
            appBar: appBar,
            body: navigationShell,
            bottomNavigationBar: NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _goToBranch,
              destinations: [
                for (final d in destinations)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: d.label,
                  ),
              ],
            ),
          );
        }

        final extended = constraints.maxWidth >= _extendedRailBreakpoint;
        return Scaffold(
          appBar: appBar,
          body: Row(
            children: [
              NavigationRail(
                extended: extended,
                // `extended` requires no per-destination labels; otherwise show them.
                labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: _goToBranch,
                destinations: [
                  for (final d in destinations)
                    NavigationRailDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: Text(d.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: navigationShell),
            ],
          ),
        );
      },
    );
  }

  List<_Destination> _destinations(AppLocalizations l10n) => [
        _Destination(Icons.savings_outlined, Icons.savings, l10n.navHome),
        _Destination(Icons.event_note_outlined, Icons.event_note, l10n.navPlan),
        _Destination(Icons.receipt_long_outlined, Icons.receipt_long, l10n.navActivity),
        _Destination(
          Icons.account_balance_wallet_outlined,
          Icons.account_balance_wallet,
          l10n.navAccounts,
        ),
      ];
}

/// One primary navigation destination — its branch order matches the router's
/// [StatefulShellBranch] order in app_router.dart.
class _Destination {
  const _Destination(this.icon, this.selectedIcon, this.label);

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

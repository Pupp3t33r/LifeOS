import 'package:flutter/material.dart';

/// Home — the monthly **savings canvas** (Phase 1 primary surface).
///
/// This is a placeholder shell. The real canvas (target / projected /
/// actual-override savings, planned purchases, recent activity) is built once
/// the Money backend exposes `MonthProjection`. See apps/wallet/PLAN.md §4.
class MonthOverviewScreen extends StatelessWidget {
  const MonthOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: const Center(
        child: Text('Savings canvas — coming soon'),
      ),
    );
  }
}

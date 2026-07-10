import 'package:flutter/material.dart';
import 'plan_board_view.dart';
import 'plan_budget_view.dart';
import 'plan_list_view.dart';

/// Plan — the planning destination (Wallet ADR-0005): one tab, three views. **List**
/// (the definitions library — Ongoing / Payment plans / Planned purchases, with create),
/// **Board** (the try-on timeline — assign wishlist wants across months), **Budget**
/// (per-category limits + a savings target). Plan is period-agnostic except Budget, which
/// carries its own period control (Money ADR-0035 relaxes ADR-0005 §2 for it).
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

enum PlanView { list, board, budget }

class _PlanScreenState extends State<PlanScreen> {
  PlanView _view = PlanView.list;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SegmentedButton<PlanView>(
            segments: const [
              ButtonSegment(
                value: PlanView.list,
                icon: Icon(Icons.list_alt_outlined),
                label: Text('List'),
              ),
              ButtonSegment(
                value: PlanView.board,
                icon: Icon(Icons.grid_view_outlined),
                label: Text('Board'),
              ),
              ButtonSegment(
                value: PlanView.budget,
                icon: Icon(Icons.tune_outlined),
                label: Text('Budget'),
              ),
            ],
            selected: {_view},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _view = s.first),
          ),
        ),
        Expanded(
          child: switch (_view) {
            PlanView.list => const PlanListView(),
            PlanView.board => const PlanBoardView(),
            PlanView.budget => const PlanBudgetView(),
          },
        ),
      ],
    );
  }
}

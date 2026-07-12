import 'package:flutter/material.dart';
import '../../../../app/theme/calm_tokens.dart';
import '../../domain/unit_dimension.dart';
import '../../domain/unit_system.dart';
import '../../domain/wishlist_schedule_chip.dart';

const List<String> _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Renders a want's schedule as month chips (Money ADR-0034 §"Board horizon" /
/// Variant B). Outline = planned (unpaid); filled ✓ = paid this cycle. `×N` is the
/// summed item count for the (month, paid, unit) group; Pieces hide their symbol
/// (`Oct ×2`), the other dimensions show it (`Oct ×0.5 kg`). The symbol is the
/// cosmetic metric/imperial label rendered from [system] — never stored.
class ScheduleChipStrip extends StatelessWidget {
  const ScheduleChipStrip({
    super.key,
    required this.chips,
    required this.system,
    this.dense = false,
  });

  final List<WishlistScheduleChip> chips;
  final UnitSystem system;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: dense ? 5 : 6,
      runSpacing: dense ? 5 : 6,
      children: [for (final c in chips) _Chip(chip: c, system: system, dense: dense)],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.chip, required this.system, required this.dense});

  final WishlistScheduleChip chip;
  final UnitSystem system;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    final label = _label();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 9,
        vertical: dense ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: chip.paid ? tokens.sage : tokens.sage.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
        border: Border.all(color: tokens.sage, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (chip.paid) ...[
            Icon(Icons.check, size: dense ? 9 : 10, color: Colors.white),
            const SizedBox(width: 2),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              fontSize: dense ? 9.5 : 10.5,
              color: chip.paid ? Colors.white : tokens.sageDeep,
            ),
          ),
        ],
      ),
    );
  }

  String _label() {
    final month = _monthNames[chip.month - 1];
    if (chip.unitDimension == UnitDimension.pieces) {
      return chip.quantity == 1 ? month : '$month ×${_formatQty(chip.quantity)}';
    }
    final symbol = chip.unitDimension.symbol(system);
    return '$month ×${_formatQty(chip.quantity)} $symbol';
  }
}

String _formatQty(double q) =>
    q == q.truncateToDouble() ? q.toInt().toString() : q.toString();

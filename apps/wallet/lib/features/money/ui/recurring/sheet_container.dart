import 'package:flutter/material.dart';
import '../../../../app/theme/calm_tokens.dart';

/// The chrome shared by every money create/resolve surface: a rounded card with a
/// grab handle (bottom-sheet only), an eyebrow title + close affordance, and a
/// keyboard-aware scrolling body. Keeps the Ongoing / Payment-plan / resolve sheets
/// visually identical without repeating the scaffolding.
class SheetContainer extends StatelessWidget {
  const SheetContainer({
    super.key,
    required this.bottomSheet,
    required this.title,
    required this.child,
    this.icon,
  });

  final bool bottomSheet;
  final String title;
  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    final radius = bottomSheet
        ? const BorderRadius.vertical(top: Radius.circular(CalmTokens.radiusLg))
        : BorderRadius.circular(CalmTokens.radiusLg);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (bottomSheet)
                Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline,
                    borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18, color: tokens.sageDeep),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        title.toUpperCase(),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: tokens.sageDeep,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

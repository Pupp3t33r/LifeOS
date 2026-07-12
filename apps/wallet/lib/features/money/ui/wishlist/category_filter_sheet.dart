import 'package:flutter/material.dart';
import '../../../../app/theme/calm_tokens.dart';
import '../../../../app/theme/category_colors.dart';
import '../../domain/category.dart';

/// The category filter (design `wishlist-filter.html`): a multi-select with **OR
/// semantics** — a want has exactly one category, so ticking several shows wants in
/// *any* chosen category. Offers **user categories only** (the system/domain ones are
/// link-derived — ADR-0024/0030 — and not hand-pickable here). Returns the new
/// selection, or null if dismissed.
Future<Set<String>?> showCategoryFilter(
  BuildContext context, {
  required List<Category> categories,
  required Set<String> selectedIds,
  required Map<String, int> counts,
}) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(CalmTokens.radiusLg)),
    ),
    builder: (context) => _CategoryFilterSheet(
      categories: categories,
      initialSelection: selectedIds,
      counts: counts,
    ),
  );
}

class _CategoryFilterSheet extends StatefulWidget {
  const _CategoryFilterSheet({
    required this.categories,
    required this.initialSelection,
    required this.counts,
  });

  final List<Category> categories;
  final Set<String> initialSelection;
  final Map<String, int> counts;

  @override
  State<_CategoryFilterSheet> createState() => _CategoryFilterSheetState();
}

class _CategoryFilterSheetState extends State<_CategoryFilterSheet> {
  late Set<String> _selected = Set.from(widget.initialSelection);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  Text('Filter by category',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (_selected.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(() => _selected = {}),
                      child: const Text('Clear'),
                    ),
                ],
              ),
            ),
            const Divider(),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final c in widget.categories)
                    _CategoryTile(
                      category: c,
                      count: widget.counts[c.id] ?? 0,
                      checked: _selected.contains(c.id),
                      onToggle: () => setState(() {
                        if (_selected.contains(c.id)) {
                          _selected.remove(c.id);
                        } else {
                          _selected.add(c.id);
                        }
                      }),
                    ),
                ],
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: Material(
                  color: tokens.sageDeep,
                  borderRadius: BorderRadius.circular(CalmTokens.radiusMd),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(_selected),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Center(
                        child: Text(
                          _selected.isEmpty
                              ? 'Show all wants'
                              : 'Show ${widget.categories.where((c) => _selected.contains(c.id)).length} categor${_selected.length == 1 ? 'y' : 'ies'}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.count,
    required this.checked,
    required this.onToggle,
  });

  final Category category;
  final int count;
  final bool checked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final color = CategoryColors.slotFor(category.id).resolve(brightness);

    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Icon(
              checked ? Icons.check_box : Icons.check_box_outline_blank,
              size: 20,
              color: checked ? CalmTokens.of(brightness).sageDeep : theme.hintColor,
            ),
            const SizedBox(width: 12),
            Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(child: Text(category.name, style: theme.textTheme.bodyMedium)),
            Text('$count',
                style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor)),
          ],
        ),
      ),
    );
  }
}

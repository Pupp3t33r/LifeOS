import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/calm_tokens.dart';
import '../../../../app/theme/category_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/categories_providers.dart';
import '../../application/wishlist_providers.dart';
import '../../domain/category.dart';
import '../../domain/money.dart';
import '../../domain/wishlist_item.dart';
import '../recurring/recurring_shared.dart' show formatMagnitude;
import 'category_filter_sheet.dart';
import 'want_row.dart';
import 'want_sheet.dart';

/// The Wishlist destination (Money ADR-0022/0034/0036, Variant B) — the browseable
/// backlog of wants. A flat list (no grouping), each row wearing a stage dot +
/// schedule chips. The default view is **Active** (Wishing + Planned + Paying off);
/// **Bought** wants hide in a collapsed row. Category filter is a multi-select
/// (OR); search matches names; sort by stage/name/estimate.
///
/// Body-only — the shell supplies the Scaffold/AppBar. A FAB offers "Add want".
class WishlistScreen extends ConsumerStatefulWidget {
  const WishlistScreen({super.key});

  @override
  ConsumerState<WishlistScreen> createState() => _WishlistScreenState();
}

enum _StatusFilter { active, wishing, planned, payingOff }

enum _Sort { stage, name, estimate }

class _WishlistScreenState extends ConsumerState<WishlistScreen> {
  _StatusFilter _status = _StatusFilter.active;
  final Set<String> _categoryIds = {};
  final TextEditingController _searchCtrl = TextEditingController();
  _Sort _sort = _Sort.stage;
  bool _boughtExpanded = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wishlist = ref.watch(wishlistProvider);
    final l10n = AppLocalizations.of(context);
    return wishlist.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(child: Text(l10n.wishlistLoadError)),
      data: (w) => _body(w.items),
    );
  }

  Widget _body(List<WishlistItem> items) {
    final tokens = CalmTokens.of(Theme.of(context).brightness);
    final wide = MediaQuery.sizeOf(context).width >= 700;

    final active = items.where((x) => x.status != WishlistCommitment.bought).toList();
    final bought = items.where((x) => x.status == WishlistCommitment.bought).toList();
    final filtered = _applyFilters(active);
    final counts = _stageCounts(items);
    final catCounts = _categoryCounts(active);

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _header(tokens, wide, counts, active)),
            SliverToBoxAdapter(child: _filterBar(tokens, wide, catCounts)),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            if (filtered.isEmpty)
              SliverFillRemaining(child: _emptyState(tokens))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverList.separated(
                  itemCount: filtered.length + (bought.isEmpty ? 0 : 1),
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    if (i == filtered.length) {
                      return _BoughtCollapse(
                        count: bought.length,
                        expanded: _boughtExpanded,
                        onTap: () => setState(() => _boughtExpanded = !_boughtExpanded),
                        total: _estimateTotal(bought),
                        children: _boughtExpanded
                            ? bought
                                .map((w) => Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: WantRow(
                                        want: w,
                                        onTap: () => showEditWant(context, w),
                                      ),
                                    ))
                                .toList()
                            : const [],
                      );
                    }
                    final want = filtered[i];
                    return WantRow(
                      want: want,
                      onTap: () => showEditWant(context, want),
                    );
                  },
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'wishlist-fab',
            onPressed: () => showAddWant(context),
            backgroundColor: tokens.clay,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  // ---- header: title + total + summary cells ----

  Widget _header(CalmTokens tokens, bool wide, Map<WishlistCommitment, int> counts,
      List<WishlistItem> active) {
    final total = _estimateTotal(active);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(l10n.navWishlist,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontFamily: CalmTokens.fontDisplay,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(width: 14),
                if (total != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                        l10n.wishlistTotalSummary(
                          formatMagnitude(total.amount, total.currency),
                          active.length,
                        ),
                      style: theme.textTheme.bodySmall?.copyWith(color: tokens.clay)),
                  ),
              ],
          ),
          const SizedBox(height: 14),
          _SummaryBar(counts: counts),
        ],
      ),
    );
  }

  // ---- filter bar ----

  Widget _filterBar(CalmTokens tokens, bool wide, Map<String, int> catCounts) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _StatusChips(
            current: _status,
            counts: {
              _StatusFilter.active: _statusCount(_StatusFilter.active),
              _StatusFilter.wishing: _statusCount(_StatusFilter.wishing),
              _StatusFilter.planned: _statusCount(_StatusFilter.planned),
              _StatusFilter.payingOff: _statusCount(_StatusFilter.payingOff),
            },
            onChanged: (v) => setState(() => _status = v),
          ),
          _CategoryTrigger(
            activeCount: _categoryIds.length,
            onTap: () => _openCategoryFilter(catCounts),
          ),
          SizedBox(
            width: wide ? 200 : 120,
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              style: theme.textTheme.bodySmall,
              decoration: InputDecoration(
                hintText: l10n.wishlistSearchHint,
                hintStyle: theme.textTheme.bodySmall?.copyWith(color: tokens.muted),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                prefixIcon: Icon(Icons.search, size: 16, color: tokens.muted),
                prefixIconConstraints: const BoxConstraints(minWidth: 32),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
                  borderSide: BorderSide(color: tokens.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
                  borderSide: BorderSide(color: tokens.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
                  borderSide: BorderSide(color: tokens.sage),
                ),
              ),
            ),
          ),
          _SortMenu(current: _sort, onChanged: (v) => setState(() => _sort = v)),
        ],
      ),
    );
  }

  // ---- filtering / sorting ----

  List<WishlistItem> _applyFilters(List<WishlistItem> active) {
    var result = active.where((w) {
      if (!_matchesStatus(w)) return false;
      if (_categoryIds.isNotEmpty &&
          (w.categoryId == null || !_categoryIds.contains(w.categoryId))) {
        return false;
      }
      final q = _searchCtrl.text.trim().toLowerCase();
      if (q.isNotEmpty && !(w.name ?? '').toLowerCase().contains(q)) return false;
      return true;
    }).toList();

    switch (_sort) {
      case _Sort.stage:
        result.sort((a, b) {
          final c = a.status.index.compareTo(b.status.index);
          return c != 0 ? c : (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase());
        });
      case _Sort.name:
        result.sort((a, b) =>
            (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase()));
      case _Sort.estimate:
        result.sort((a, b) => (b.estimate?.amount ?? 0).compareTo(a.estimate?.amount ?? 0));
    }
    return result;
  }

  bool _matchesStatus(WishlistItem w) => switch (_status) {
        _StatusFilter.active => w.status != WishlistCommitment.bought,
        _StatusFilter.wishing => w.status == WishlistCommitment.idle,
        _StatusFilter.planned => w.status == WishlistCommitment.planned,
        _StatusFilter.payingOff => w.status == WishlistCommitment.financed,
      };

  int _statusCount(_StatusFilter f) {
    final items = ref.read(wishlistProvider).value?.items ?? const [];
    var n = 0;
    for (final w in items) {
      switch (f) {
        case _StatusFilter.active:
          if (w.status != WishlistCommitment.bought) n++;
        case _StatusFilter.wishing:
          if (w.status == WishlistCommitment.idle) n++;
        case _StatusFilter.planned:
          if (w.status == WishlistCommitment.planned) n++;
        case _StatusFilter.payingOff:
          if (w.status == WishlistCommitment.financed) n++;
      }
    }
    return n;
  }

  Map<WishlistCommitment, int> _stageCounts(List<WishlistItem> items) {
    final counts = <WishlistCommitment, int>{};
    for (final w in items) {
      counts[w.status] = (counts[w.status] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, int> _categoryCounts(List<WishlistItem> items) {
    final counts = <String, int>{};
    for (final w in items) {
      if (w.categoryId != null) counts[w.categoryId!] = (counts[w.categoryId!] ?? 0) + 1;
    }
    return counts;
  }

  Money? _estimateTotal(List<WishlistItem> items) {
    Money? total;
    for (final w in items) {
      final e = w.estimate;
      if (e == null) continue;
      if (total == null) {
        total = e;
      } else if (total.currency == e.currency) {
        total = Money(amount: total.amount + e.amount, currency: total.currency);
      }
    }
    return total;
  }

  Future<void> _openCategoryFilter(Map<String, int> counts) async {
    final all = ref.read(categoriesProvider).value ?? const <Category>[];
    final userCats = [for (final c in all) if (!c.isSystem && !c.archived) c];
    final result = await showCategoryFilter(
      context,
      categories: userCats,
      selectedIds: _categoryIds,
      counts: counts,
    );
    if (result != null) setState(() => _categoryIds..clear()..addAll(result));
  }

  Widget _emptyState(CalmTokens tokens) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_outline, size: 48, color: tokens.muted.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(l10n.wishlistEmptyTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(l10n.wishlistEmptySubtitle,
                style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted)),
          ],
        ),
      ),
    );
  }
}

// ---- summary bar ----

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.counts});

  final Map<WishlistCommitment, int> counts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    final brightness = theme.brightness;
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border.all(color: tokens.line),
        borderRadius: BorderRadius.circular(CalmTokens.radiusMd),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _cell(l10n.stageWishing, counts[WishlistCommitment.idle] ?? 0, tokens.muted, theme),
            _divider(tokens),
            _cell(l10n.stagePlanned, counts[WishlistCommitment.planned] ?? 0, tokens.clay, theme),
            _divider(tokens),
            _cell(l10n.stagePayingOff, counts[WishlistCommitment.financed] ?? 0,
                CategoryPalette.denim.resolve(brightness), theme),
            _divider(tokens),
            _cell(l10n.stageBought, counts[WishlistCommitment.bought] ?? 0, tokens.sage, theme),
          ],
        ),
      ),
    );
  }

  Widget _cell(String label, int count, Color color, ThemeData theme) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 7),
              Text(label.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: theme.hintColor,
                      letterSpacing: 0.8)),
            ]),
            const SizedBox(height: 7),
            Text('$count',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontFamily: CalmTokens.fontDisplay,
                  fontWeight: FontWeight.w700,
                )),
          ],
        ),
      ),
    );
  }

  Widget _divider(CalmTokens tokens) =>
      VerticalDivider(width: 1, color: tokens.line, indent: 8, endIndent: 8);
}

// ---- status filter chips ----

class _StatusChips extends StatelessWidget {
  const _StatusChips({required this.current, required this.counts, required this.onChanged});

  final _StatusFilter current;
  final Map<_StatusFilter, int> counts;
  final ValueChanged<_StatusFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final f in _StatusFilter.values)
            _chip(context, f, theme, tokens),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, _StatusFilter f, ThemeData theme, CalmTokens tokens) {
    final selected = f == current;
    final l10n = AppLocalizations.of(context);
    final label = switch (f) {
      _StatusFilter.active => l10n.stageActive,
      _StatusFilter.wishing => l10n.stageWishing,
      _StatusFilter.planned => l10n.stagePlanned,
      _StatusFilter.payingOff => l10n.stagePayingOff,
    };
    return InkWell(
      borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
      onTap: () => onChanged(f),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? tokens.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
          boxShadow: selected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 2)]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: selected ? tokens.ink : tokens.muted,
                )),
            const SizedBox(width: 5),
            Text('${counts[f]}',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  color: selected ? tokens.sageDeep : tokens.muted,
                )),
          ],
        ),
      ),
    );
  }
}

// ---- category trigger ----

class _CategoryTrigger extends StatelessWidget {
  const _CategoryTrigger({required this.activeCount, required this.onTap});

  final int activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    final l10n = AppLocalizations.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: tokens.surface,
          border: Border.all(color: tokens.line),
          borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_list, size: 14, color: tokens.muted),
            const SizedBox(width: 7),
            Text(activeCount == 0 ? l10n.wishlistAllCategories : l10n.wishlistCategoryCount(activeCount),
                style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600, color: tokens.muted)),
            const SizedBox(width: 5),
            Icon(Icons.arrow_drop_down, size: 16, color: tokens.muted),
          ],
        ),
      ),
    );
  }
}

// ---- sort menu ----

class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.current, required this.onChanged});

  final _Sort current;
  final ValueChanged<_Sort> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<_Sort>(
      onSelected: onChanged,
      color: tokens.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CalmTokens.radiusSm)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: tokens.surface,
          border: Border.all(color: tokens.line),
          borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort, size: 14, color: tokens.muted),
            const SizedBox(width: 7),
            Text(l10n.wishlistSortLabel(_label(l10n, current)),
                style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600, color: tokens.muted)),
          ],
        ),
      ),
      itemBuilder: (_) => [
        for (final s in _Sort.values)
          PopupMenuItem(value: s, child: Text(_label(l10n, s))),
      ],
    );
  }

  String _label(AppLocalizations l10n, _Sort s) => switch (s) {
        _Sort.stage => l10n.sortStage,
        _Sort.name => l10n.sortName,
        _Sort.estimate => l10n.sortEstimate,
      };
}

// ---- bought collapse ----

class _BoughtCollapse extends StatelessWidget {
  const _BoughtCollapse({
    required this.count,
    required this.expanded,
    required this.onTap,
    required this.children,
    required this.total,
  });

  final int count;
  final bool expanded;
  final VoidCallback onTap;
  final List<Widget> children;
  final Money? total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CalmTokens.of(theme.brightness);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(CalmTokens.radiusMd),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: tokens.line, style: expanded ? BorderStyle.solid : BorderStyle.none),
              borderRadius: expanded
                  ? BorderRadius.circular(CalmTokens.radiusMd)
                  : BorderRadius.circular(CalmTokens.radiusMd),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: tokens.sage.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check, size: 12, color: tokens.sageDeep),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: l10n.wishlistBoughtCount(count),
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: l10n.wishlistBoughtHiddenSuffix),
                      ],
                    ),
                  ),
                ),
                if (total != null)
                  Text('−${formatMagnitude(total!.amount, total!.currency)}',
                      style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted)),
                const SizedBox(width: 8),
                Icon(expanded ? Icons.expand_less : Icons.chevron_right,
                    size: 18, color: tokens.muted),
              ],
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}

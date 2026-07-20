import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/calm_tokens.dart';
import '../../../../app/theme/category_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/categories_providers.dart';
import '../../application/category_colors_provider.dart';
import '../../domain/category.dart';

/// Settings → Categories (Wallet ADR-0008). A dedicated surface above the shell
/// where the user searches, recolours, renames, creates, and archives/restores
/// categories. Colour is device-local (recolour is instant, offline); the rest is
/// queued on the outbox (Money ADR-0033).
///
/// Design spec: apps/wallet/docs/design/settings/categories.html.
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  static const double _contentMaxWidth = 640;

  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  /// The category whose inline colour palette is open, or null when none is.
  String? _expandedId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(Category c) =>
      _query.isEmpty || c.name.toLowerCase().contains(_query);

  void _toggleExpanded(String id) {
    setState(() => _expandedId = _expandedId == id ? null : id);
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ---- write handlers --------------------------------------------------------

  Future<void> _recolor(Category category, CategoryPalette slot) async {
    await ref.read(categoryColorsProvider.notifier).setSlot(category.id, slot);
  }

  Future<void> _createCategory() async {
    final l10n = AppLocalizations.of(context);
    final name = await _promptName(title: l10n.categoriesNewButton, cta: l10n.categoriesCreateCta);
    if (name == null) return;
    try {
      await ref.read(categoriesControllerProvider.notifier).create(name);
    } on CategoryNameConflict {
      _snack(l10n.categoriesNameConflictError);
    }
  }

  Future<void> _renameCategory(Category category) async {
    final l10n = AppLocalizations.of(context);
    final name = await _promptName(
      title: l10n.categoriesRenameTitle,
      cta: l10n.createSaveButton,
      initial: category.name,
      excludeId: category.id,
    );
    if (name == null || name == category.name) return;
    try {
      await ref.read(categoriesControllerProvider.notifier).rename(category.id, name);
    } on CategoryNameConflict {
      _snack(l10n.categoriesNameConflictError);
    }
  }

  Future<void> _archive(Category category) async {
    setState(() => _expandedId = null);
    await ref.read(categoriesControllerProvider.notifier).archive(category.id);
    if (!mounted) return;
    _snack(AppLocalizations.of(context).categoriesArchivedSnack(category.name));
  }

  Future<void> _unarchive(Category category) async {
    setState(() => _expandedId = null);
    await ref.read(categoriesControllerProvider.notifier).unarchive(category.id);
    if (!mounted) return;
    _snack(AppLocalizations.of(context).categoriesRestoredSnack(category.name));
  }

  /// A name dialog with live uniqueness validation (the client mirror of Money
  /// ADR-0033). Returns the trimmed name, or null if cancelled.
  Future<String?> _promptName({
    required String title,
    required String cta,
    String? initial,
    String? excludeId,
  }) {
    final controller = TextEditingController(text: initial);
    final notifier = ref.read(categoriesControllerProvider.notifier);
    final l10n = AppLocalizations.of(context);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final value = controller.text.trim();
            final unchanged = initial != null && value == initial.trim();
            final available =
                value.isEmpty || unchanged || notifier.nameAvailable(value, excludeId: excludeId);
            final canSubmit = value.isNotEmpty && available;
            return AlertDialog(
              title: Text(title),
              content: TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setDialogState(() {}),
                onSubmitted: (_) {
                  if (canSubmit) Navigator.of(context).pop(value);
                },
                decoration: InputDecoration(
                  hintText: l10n.categoriesNameHint,
                  errorText: available ? null : l10n.categoriesNameConflictError,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.commonCancel),
                ),
                FilledButton(
                  onPressed: canSubmit ? () => Navigator.of(context).pop(value) : null,
                  child: Text(cta),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---- build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    // Rebuild when a colour override changes so swatches repaint immediately.
    ref.watch(categoryColorsProvider);
    final categories = ref.watch(categoriesControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.categoriesScreenTitle)),
      body: SafeArea(
        child: categories.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _ErrorState(onRetry: () => ref.invalidate(categoriesControllerProvider)),
          data: (all) => _buildList(theme, all),
        ),
      ),
    );
  }

  Widget _buildList(ThemeData theme, List<Category> all) {
    int byName(Category a, Category b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());

    final yours = [for (final c in all) if (!c.isSystem && !c.archived && _matches(c)) c]..sort(byName);
    final system = [for (final c in all) if (c.isSystem && _matches(c)) c];
    final archived = [for (final c in all) if (!c.isSystem && c.archived && _matches(c)) c]..sort(byName);

    final searching = _query.isNotEmpty;
    final nothingMatches = searching && yours.isEmpty && system.isEmpty && archived.isEmpty;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SearchField(
          controller: _searchController,
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 48),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (nothingMatches)
                        _NoMatches(query: _query)
                      else ...[
                        if (yours.isNotEmpty || !searching) ...[
                          _Eyebrow(label: l10n.categoriesYoursLabel),
                          if (yours.isNotEmpty) _card([for (final c in yours) _row(theme, c)]),
                          if (!searching) _GhostRow(onTap: _createCategory),
                        ],
                        if (system.isNotEmpty) ...[
                          _Eyebrow(label: l10n.categoriesSystemLabel, sub: l10n.categoriesSystemSub),
                          _card([for (final c in system) _row(theme, c)]),
                        ],
                        if (archived.isNotEmpty) ...[
                          _Eyebrow(
                            label: l10n.categoriesArchivedLabel,
                            sub: searching
                                ? l10n.categoriesArchivedInResults
                                : l10n.categoriesArchivedCount(archived.length),
                          ),
                          _card([for (final c in archived) _row(theme, c)]),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _card(List<Widget> rows) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(CalmTokens.radiusLg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: theme.colorScheme.outline),
            rows[i],
          ],
        ],
      ),
    );
  }

  Widget _row(ThemeData theme, Category category) {
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final expanded = _expandedId == category.id;
    final slot = CategoryColors.slotFor(category.id);
    final dim = category.archived;

    final header = InkWell(
      onTap: () => _toggleExpanded(category.id),
      child: Container(
        color: expanded ? CalmTokens.of(theme.brightness).sageDeep.withValues(alpha: 0.08) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Opacity(
              opacity: dim ? 0.45 : 1,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: slot.resolve(theme.brightness),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 0, spreadRadius: 1)],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                category.name,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: dim ? FontWeight.w400 : FontWeight.w500,
                  color: dim ? muted : theme.colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (category.isSystem)
              _SystemChip(muted: muted)
            else
              Icon(expanded ? Icons.expand_less : Icons.chevron_right, size: 20, color: muted),
          ],
        ),
      ),
    );

    if (!expanded) return header;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [header, _colourDrawer(theme, category, slot)],
    );
  }

  Widget _colourDrawer(ThemeData theme, Category category, CategoryPalette selected) {
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final sage = CalmTokens.of(theme.brightness).sageDeep;
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: sage.withValues(alpha: 0.06),
        border: Border(top: BorderSide(color: theme.colorScheme.outline)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(l10n.categoriesColorLabel,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: muted, letterSpacing: 1.4, fontWeight: FontWeight.w600)),
              Text(
                _slotLabel(selected),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontFamily: CalmTokens.fontDisplay,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in CategoryPalette.values)
                _PaletteChip(
                  color: s.resolve(theme.brightness),
                  selected: s == selected,
                  onTap: () => _recolor(category, s),
                ),
            ],
          ),
          if (!category.isSystem) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                _LinkAction(label: l10n.categoriesRenameLink, color: sage, onTap: () => _renameCategory(category)),
                const SizedBox(width: 22),
                category.archived
                    ? _LinkAction(label: l10n.categoriesUnarchiveLink, color: sage, onTap: () => _unarchive(category))
                    : _LinkAction(
                        label: l10n.categoriesArchiveLink,
                        color: CalmTokens.of(theme.brightness).clay,
                        onTap: () => _archive(category)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _slotLabel(CategoryPalette slot) =>
      slot.name[0].toUpperCase() + slot.name.substring(1);
}

// ---- chrome ------------------------------------------------------------------

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: l10n.categoriesSearchHint,
          prefixIcon: const Icon(Icons.search, size: 20),
          isDense: true,
          filled: true,
          fillColor: CalmTokens.of(theme.brightness).bone,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(CalmTokens.radiusSm),
            borderSide: BorderSide(color: theme.colorScheme.outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(CalmTokens.radiusSm),
            borderSide: BorderSide(color: theme.colorScheme.outline),
          ),
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.label, this.sub});

  final String label;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 20, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: muted,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(width: 8),
            Text(sub!, style: theme.textTheme.labelSmall?.copyWith(color: muted.withValues(alpha: 0.85))),
          ],
        ],
      ),
    );
  }
}

class _GhostRow extends StatelessWidget {
  const _GhostRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sage = CalmTokens.of(theme.brightness).sageDeep;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CalmTokens.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CalmTokens.radiusMd),
            border: Border.all(color: sage.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 18, color: sage),
              const SizedBox(width: 8),
              Text(l10n.categoriesNewButton,
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600, color: sage)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SystemChip extends StatelessWidget {
  const _SystemChip({required this.muted});

  final Color muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: muted.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(CalmTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 12, color: muted),
          const SizedBox(width: 5),
          Text(AppLocalizations.of(context).addEntrySystemTag,
              style: theme.textTheme.labelSmall?.copyWith(color: muted)),
        ],
      ),
    );
  }
}

class _PaletteChip extends StatelessWidget {
  const _PaletteChip({required this.color, required this.selected, required this.onTap});

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(9),
          border: selected
              ? Border.all(color: theme.colorScheme.onSurface, width: 2)
              : Border.all(color: Colors.black.withValues(alpha: 0.1)),
        ),
      ),
    );
  }
}

class _LinkAction extends StatelessWidget {
  const _LinkAction({required this.label, required this.color, required this.onTap});

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          fontFamily: CalmTokens.fontDisplay,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Text(
          l10n.categoriesNoMatches(query),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.addEntryCategoryLoadError,
                style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: Text(l10n.categoriesRetryButton)),
          ],
        ),
      ),
    );
  }
}

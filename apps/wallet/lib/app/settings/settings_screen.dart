import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/money/application/preferences_providers.dart';
import '../../features/money/data/preferences_repository.dart';
import '../../features/money/domain/unit_system.dart';
import '../../features/security/application/security_providers.dart';
import '../../l10n/app_localizations.dart';
import '../locale/locale_controller.dart';
import '../theme/calm_tokens.dart';
import '../theme/theme_controller.dart';

/// Settings — secondary surface reached from the shell's gear button, not a
/// primary nav destination (see apps/wallet/PLAN.md §13). Full-screen with its own
/// app bar / back affordance since it sits above the shell.
///
/// A single scrolling page of grouped settings (IDE/Discord-style): a filter box
/// narrows by name, and a contents rail on wide screens jumps to — and highlights —
/// the group in view. Hosts the settings that have a working write path today:
/// theme + language (device-local), display currency + month-start (Money ADR-0013),
/// and the biometric app-lock (native only, ADR-0014). Account name / opening balance
/// are immutable server-side, so they are intentionally absent.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const double _tocBreakpoint = 760;
  static const double _contentMaxWidth = 640;

  /// Distance from the top of the content viewport at which a group header counts
  /// as "the one in view" for the contents rail highlight.
  static const double _activeAnchor = 96;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final Map<String, GlobalKey> _groupKeys = {};

  String _query = '';
  String? _activeGroupId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(String id) => _groupKeys.putIfAbsent(id, () => GlobalKey());

  /// Pick the last group whose header has scrolled to or past the anchor line —
  /// that's the one the reader is currently sitting in.
  void _onScroll() {
    String? active;
    for (final entry in _groupKeys.entries) {
      final box = entry.value.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final dy = box.localToGlobal(Offset.zero).dy;
      if (dy <= _activeAnchor + _appBarInset(context)) active = entry.key;
    }
    if (active != null && active != _activeGroupId) {
      setState(() => _activeGroupId = active);
    }
  }

  double _appBarInset(BuildContext context) =>
      MediaQuery.paddingOf(context).top + kToolbarHeight;

  Future<void> _scrollToGroup(String id) async {
    setState(() => _activeGroupId = id);
    final context = _keyFor(id).currentContext;
    if (context == null) return;
    await Scrollable.ensureVisible(
      context,
      alignment: 0.02,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  // ---- write handlers --------------------------------------------------------

  Future<void> _setDisplayCurrency(String code) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(preferencesRepositoryProvider).setDisplayCurrency(code);
      ref.invalidate(preferencesProvider);
    } catch (_) {
      _snack(l10n.settingsCurrencyUpdateError);
    }
  }

  Future<void> _setMonthStartDay(int day) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(preferencesRepositoryProvider).setMonthStartDay(day);
      ref.invalidate(preferencesProvider);
    } on DioException catch (error) {
      _snack(error.response?.statusCode == 409
          ? l10n.settingsMonthStartLockedError
          : l10n.settingsMonthStartUpdateError);
    } catch (_) {
      _snack(l10n.settingsMonthStartUpdateError);
    }
  }

  Future<void> _setUnitSystem(UnitSystem system) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(preferencesRepositoryProvider).setUnitSystem(system);
      ref.invalidate(preferencesProvider);
    } catch (_) {
      _snack(l10n.settingsUnitSystemUpdateError);
    }
  }

  Future<void> _setAppLock(bool value) async {
    await ref.read(appLockStoreProvider).setEnabled(value);
    ref.invalidate(appLockEnabledProvider);
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ---- build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groups = _buildGroups(context, l10n);

    final visible = [
      for (final group in groups)
        (group: group, items: group.items.where((x) => x.matches(_query)).toList())
    ].where((x) => x.items.isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showToc = constraints.maxWidth >= _tocBreakpoint;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SearchField(
                  controller: _searchController,
                  hintText: l10n.settingsSearchHint,
                  onChanged: (v) {
                    setState(() => _query = v.trim().toLowerCase());
                  },
                ),
                Expanded(
                  child: visible.isEmpty
                      ? _NoMatches(query: _query, l10n: l10n)
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showToc)
                              _ContentsRail(
                                groups: [for (final v in visible) v.group],
                                activeId: _activeGroupId,
                                onSelect: _scrollToGroup,
                              ),
                            Expanded(
                              child: ListView(
                                controller: _scrollController,
                                padding: EdgeInsets.fromLTRB(showToc ? 8 : 18, 8, 18, 48),
                                children: [
                                  for (final v in visible)
                                    Center(
                                      child: ConstrainedBox(
                                        constraints:
                                            const BoxConstraints(maxWidth: _contentMaxWidth),
                                        child: _GroupSection(
                                          key: _keyFor(v.group.id),
                                          group: v.group,
                                          items: v.items,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Assembles the groups with their live controls. Called each build so the
  /// controls reflect the latest provider state.
  List<_Group> _buildGroups(BuildContext context, AppLocalizations l10n) {
    final themeMode = ref.watch(themeControllerProvider);
    final locale = ref.watch(localeControllerProvider);
    final prefs = ref.watch(preferencesProvider);
    final prefsValue = prefs.value;
    final prefsBusy = prefs.isLoading;
    final biometricSupported =
        ref.watch(biometricSupportedProvider).value ?? false;
    final appLockEnabled = ref.watch(appLockEnabledProvider).value ?? false;

    final appearance = _Group(
      id: 'appearance',
      title: l10n.settingsGroupAppearance,
      icon: Icons.palette_outlined,
      items: [
        _Item(
          title: l10n.settingsThemeTitle,
          subtitle: l10n.settingsThemeSubtitle,
          keywords: const ['dark', 'light', 'mode', 'system', 'appearance'],
          stacked: true,
          control: _ThemeControl(
            mode: themeMode,
            l10n: l10n,
            onChanged: (m) => ref.read(themeControllerProvider.notifier).setThemeMode(m),
          ),
        ),
        _Item(
          title: l10n.settingsLanguageTitle,
          subtitle: l10n.settingsLanguageSubtitle,
          keywords: const ['locale', 'english', 'russian'],
          control: _LocaleControl(
            locale: locale,
            l10n: l10n,
            onChanged: (loc) =>
                ref.read(localeControllerProvider.notifier).setLocale(loc),
          ),
        ),
      ],
    );

    final money = _Group(
      id: 'money',
      title: l10n.settingsGroupMoney,
      icon: Icons.account_balance_wallet_outlined,
      items: [
        _Item(
          title: l10n.settingsCurrencyTitle,
          subtitle: l10n.settingsCurrencySubtitle,
          keywords: const ['currency', 'usd', 'eur', 'money'],
          control: _CurrencyControl(
            value: prefsValue?.displayCurrency,
            enabled: !prefsBusy,
            onChanged: _setDisplayCurrency,
          ),
        ),
        _Item(
          title: l10n.settingsMonthStartTitle,
          subtitle: l10n.settingsMonthStartSubtitle,
          keywords: const ['period', 'month', 'start', 'billing'],
          control: _MonthStartControl(
            value: prefsValue?.monthStartDay ?? 1,
            enabled: !prefsBusy,
            onChanged: _setMonthStartDay,
            l10n: l10n,
          ),
        ),
        _Item(
          title: l10n.settingsUnitSystemTitle,
          subtitle: l10n.settingsUnitSystemSubtitle,
          keywords: const ['unit', 'metric', 'imperial', 'kg', 'lb', 'quantity'],
          stacked: true,
          control: _UnitSystemControl(
            value: prefsValue?.unitSystem ?? UnitSystem.metric,
            enabled: !prefsBusy,
            onChanged: _setUnitSystem,
            l10n: l10n,
          ),
        ),
        _Item(
          title: l10n.settingsCategoriesTitle,
          subtitle: l10n.settingsCategoriesSubtitle,
          keywords: const ['category', 'categories', 'colour', 'color', 'archive', 'tag'],
          onTap: () => context.push('/settings/categories'),
          control: const Icon(Icons.chevron_right),
        ),
        _Item(
          title: l10n.settingsRatesTitle,
          subtitle: l10n.settingsRatesSubtitle,
          keywords: const ['rate', 'rates', 'fx', 'exchange', 'currency', 'conversion'],
          onTap: () => context.push('/settings/rates'),
          control: const Icon(Icons.chevron_right),
        ),
      ],
    );

    return [
      appearance,
      money,
      if (biometricSupported)
        _Group(
          id: 'security',
          title: l10n.settingsGroupSecurity,
          icon: Icons.lock_outline,
          items: [
            _Item(
              title: l10n.settingsAppLockTitle,
              subtitle: l10n.settingsAppLockSubtitle,
              keywords: const ['biometric', 'face', 'fingerprint', 'lock', 'security'],
              control: Switch(value: appLockEnabled, onChanged: _setAppLock),
            ),
          ],
        ),
    ];
  }
}

// ---- models ------------------------------------------------------------------

class _Group {
  const _Group({required this.id, required this.title, required this.icon, required this.items});

  final String id;
  final String title;
  final IconData icon;
  final List<_Item> items;
}

class _Item {
  const _Item({
    required this.title,
    required this.subtitle,
    required this.control,
    this.stacked = false,
    this.keywords = const <String>[],
    this.onTap,
  });

  final String title;
  final String subtitle;
  final Widget control;

  /// When set, the whole row is tappable and navigates (rather than hosting an
  /// inline control) — e.g. the Categories row → `/settings/categories`.
  final VoidCallback? onTap;

  /// True for wide controls (e.g. the theme segments) that read better on their own
  /// line under the label than squeezed into a trailing slot.
  final bool stacked;
  final List<String> keywords;

  bool matches(String query) =>
      query.isEmpty ||
      '$title $subtitle ${keywords.join(' ')}'.toLowerCase().contains(query);
}

// ---- chrome ------------------------------------------------------------------

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
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

/// The contents rail — one row per group; tap to jump, highlighted while in view.
class _ContentsRail extends StatelessWidget {
  const _ContentsRail({required this.groups, required this.activeId, required this.onSelect});

  final List<_Group> groups;
  final String? activeId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    // Before the first scroll (or on a page too short to scroll) nothing has been
    // marked active — fall back to the first group so the rail is never blank.
    final effectiveActive = activeId ?? (groups.isEmpty ? null : groups.first.id);
    return SizedBox(
      width: 208,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 8, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final group in groups)
              _RailItem(
                title: group.title,
                icon: group.icon,
                selected: group.id == effectiveActive,
                mutedColor: muted,
                onTap: () => onSelect(group.id),
              ),
          ],
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.title,
    required this.icon,
    required this.selected,
    required this.mutedColor,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool selected;
  final Color mutedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected ? theme.colorScheme.primary : mutedColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(CalmTokens.radiusSm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One group: a header (icon + title) and a card of setting rows.
class _GroupSection extends StatelessWidget {
  const _GroupSection({super.key, required this.group, required this.items});

  final _Group group;
  final List<_Item> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Row(
              children: [
                Icon(group.icon, size: 18, color: muted),
                const SizedBox(width: 9),
                Text(
                  group.title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: muted,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(CalmTokens.radiusLg),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: theme.colorScheme.outline),
                  _SettingRow(item: items[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.item});

  final _Item item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.title,
            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(item.subtitle, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
      ],
    );

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: item.stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [label, const SizedBox(height: 12), item.control],
            )
          : Row(
              children: [
                Expanded(child: label),
                const SizedBox(width: 12),
                item.control,
              ],
            ),
    );

    if (item.onTap == null) return content;
    return InkWell(onTap: item.onTap, child: content);
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.query, required this.l10n});

  final String query;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          l10n.settingsNoMatches(query),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        ),
      ),
    );
  }
}

// ---- controls ----------------------------------------------------------------

class _ThemeControl extends StatelessWidget {
  const _ThemeControl({required this.mode, required this.l10n, required this.onChanged});

  final ThemeMode mode;
  final AppLocalizations l10n;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ThemeMode>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(value: ThemeMode.system, label: Text(l10n.commonSystem)),
        ButtonSegment(value: ThemeMode.light, label: Text(l10n.settingsThemeLight)),
        ButtonSegment(value: ThemeMode.dark, label: Text(l10n.settingsThemeDark)),
      ],
      selected: {mode},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _LocaleControl extends StatelessWidget {
  const _LocaleControl({required this.locale, required this.l10n, required this.onChanged});

  final Locale? locale;
  final AppLocalizations l10n;
  final ValueChanged<Locale?> onChanged;

  @override
  Widget build(BuildContext context) {
    return _Dropdown<String>(
      value: locale?.languageCode ?? 'system',
      items: [
        ('system', l10n.commonSystem),
        ('en', l10n.languageNameEnglish),
        ('ru', l10n.languageNameRussian),
      ],
      onChanged: (code) => onChanged(code == 'system' ? null : Locale(code)),
    );
  }
}

class _CurrencyControl extends StatelessWidget {
  const _CurrencyControl({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String? value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  static const List<String> _codes = ['USD', 'EUR', 'GBP', 'PLN', 'JPY', 'CAD'];

  @override
  Widget build(BuildContext context) {
    return _Dropdown<String>(
      value: _codes.contains(value) ? value : null,
      hint: '—',
      items: [for (final code in _codes) (code, code)],
      onChanged: enabled ? (code) => onChanged(code) : null,
    );
  }
}

class _MonthStartControl extends StatelessWidget {
  const _MonthStartControl({
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.l10n,
  });

  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return _Dropdown<int>(
      value: value,
      items: [
        for (var day = 1; day <= 31; day++)
          (day, day == 1 ? l10n.settingsMonthStartCalendarLabel : '$day'),
      ],
      onChanged: enabled ? (day) => onChanged(day) : null,
    );
  }
}

class _UnitSystemControl extends StatelessWidget {
  const _UnitSystemControl({
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.l10n,
  });

  final UnitSystem value;
  final bool enabled;
  final ValueChanged<UnitSystem> onChanged;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<UnitSystem>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: UnitSystem.metric,
          label: Text(l10n.unitSystemMetric),
        ),
        ButtonSegment(
          value: UnitSystem.imperial,
          label: Text(l10n.unitSystemImperial),
        ),
      ],
      selected: {value},
      onSelectionChanged: enabled ? (s) => onChanged(s.first) : null,
    );
  }
}

/// A borderless dropdown sized for the trailing slot of a setting row. A null
/// [onChanged] renders it disabled.
class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({required this.value, required this.items, required this.onChanged, this.hint});

  final T? value;
  final List<(T, String)> items;
  final ValueChanged<T>? onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        hint: hint == null ? null : Text(hint!),
        borderRadius: BorderRadius.circular(CalmTokens.radiusMd),
        isDense: true,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontFamily: CalmTokens.fontDisplay,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        items: [
          for (final (item, label) in items)
            DropdownMenuItem<T>(value: item, child: Text(label)),
        ],
        onChanged: onChanged == null
            ? null
            : (selected) {
                if (selected != null) onChanged!(selected);
              },
      ),
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/category_colors.dart';
import '../data/category_color_store.dart';

final categoryColorStoreProvider = Provider<CategoryColorStore>(
  (ref) => CategoryColorStore(),
);

/// The device-local category colour overrides (Wallet ADR-0003), loaded from
/// [CategoryColorStore] and mirrored into the synchronous [CategoryColors]
/// resolver that widgets read in `build`.
///
/// Watch this wherever category colours render so the surface rebuilds the moment
/// an override changes; the colour value itself still comes through
/// `CategoryColors.slotFor(id)`. Recolour goes through [setSlot], which persists,
/// updates the resolver, and refreshes this state.
class CategoryColorsController extends AsyncNotifier<Map<String, CategoryPalette>> {
  @override
  Future<Map<String, CategoryPalette>> build() async {
    final overrides = await ref.watch(categoryColorStoreProvider).readAll();
    CategoryColors.setAll(overrides);
    return overrides;
  }

  /// Set or clear [categoryId]'s override to [slot] (null = revert to default).
  Future<void> setSlot(String categoryId, CategoryPalette? slot) async {
    await ref.read(categoryColorStoreProvider).setSlot(categoryId, slot);
    CategoryColors.setOne(categoryId, slot);
    final next = {...(state.value ?? const {})};
    if (slot == null) {
      next.remove(categoryId);
    } else {
      next[categoryId] = slot;
    }
    state = AsyncData(next);
  }
}

final categoryColorsProvider =
    AsyncNotifierProvider<CategoryColorsController, Map<String, CategoryPalette>>(
  CategoryColorsController.new,
);

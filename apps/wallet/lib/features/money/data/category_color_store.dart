import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../app/theme/category_colors.dart';

/// Device-local persistence of category colour overrides (Wallet ADR-0003): a map
/// `categoryId → palette slot`, stored as one JSON blob in secure storage.
///
/// Like `ThemeStore`/`LocaleStore`, colour is a **per-device display preference**
/// and never travels to Money (Wallet ADR-0003 / Money ADR-0024). A category with
/// no entry here falls back to its deterministic default (`CategoryPalette.forId`).
class CategoryColorStore {
  CategoryColorStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _key = 'category_colours';

  /// The stored overrides, dropping any entry whose slot name no longer resolves.
  Future<Map<String, CategoryPalette>> readAll() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final result = <String, CategoryPalette>{};
    decoded.forEach((id, slotName) {
      final slot = CategoryPalette.byName(slotName as String);
      if (slot != null) result[id] = slot;
    });
    return result;
  }

  /// Set (or, when [slot] is null, clear) the override for [categoryId].
  Future<void> setSlot(String categoryId, CategoryPalette? slot) async {
    final map = await readAll();
    if (slot == null) {
      map.remove(categoryId);
    } else {
      map[categoryId] = slot;
    }
    await _storage.write(
      key: _key,
      value: jsonEncode({for (final e in map.entries) e.key: e.value.name}),
    );
  }
}

import 'package:flutter/material.dart';

/// The curated category colour palette — **Wallet ADR-0003**.
///
/// Twelve fixed slots, each with a light- and dark-mode value tuned to read on
/// the Calm canvas. Colour is a *client/display* concern: it never travels to
/// the Money domain. A category's colour is either an explicit user choice
/// (stored device-local, ADR-0003) or, absent one, derived deterministically
/// from its id via [forId] so the same category always looks the same.
///
/// Slot names are the palette's own vocabulary and are independent of the Calm
/// theme tokens (which share some names by coincidence, not by binding).
enum CategoryPalette {
  sage(Color(0xFF6E8E78), Color(0xFF8FB39E)),
  teal(Color(0xFF4F8A82), Color(0xFF79B3AA)),
  denim(Color(0xFF6480A0), Color(0xFF8BA6C4)),
  indigo(Color(0xFF76739E), Color(0xFFA19CC2)),
  plum(Color(0xFF9B6E8E), Color(0xFFC193B2)),
  rose(Color(0xFFBB7081), Color(0xFFDA98A6)),
  rust(Color(0xFFB0654A), Color(0xFFD08C73)),
  clay(Color(0xFFC2855A), Color(0xFFDBA877)),
  ochre(Color(0xFFB59A4E), Color(0xFFD6BB72)),
  olive(Color(0xFF899050), Color(0xFFAEB477)),
  stone(Color(0xFF8C8275), Color(0xFFADA293)),
  slate(Color(0xFF7C8696), Color(0xFF9FA9B8));

  const CategoryPalette(this.light, this.dark);

  /// Light-mode value.
  final Color light;

  /// Dark-mode value (lifted so it holds up on the dark canvas).
  final Color dark;

  /// The value for the active [brightness].
  Color resolve(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// The value for the active theme.
  Color of(BuildContext context) => resolve(Theme.of(context).brightness);

  /// Deterministic default slot for a category that has no explicit colour —
  /// stable for a given id, so a category keeps its colour across sessions and
  /// devices until the user overrides it.
  static CategoryPalette forId(String categoryId) =>
      values[categoryId.hashCode.abs() % values.length];

  /// The slot for a stored override name (e.g. `'clay'`), or null if the name
  /// doesn't match a slot (defensive against stale/corrupt storage).
  static CategoryPalette? byName(String name) {
    for (final slot in values) {
      if (slot.name == name) return slot;
    }
    return null;
  }
}

/// The app-wide resolver for a category's colour (Wallet ADR-0003): a device-local
/// user override if one exists, else the deterministic default from the id.
///
/// Overrides live in `flutter_secure_storage` (see `CategoryColorStore`); this
/// in-memory copy is what widgets read synchronously in `build`. It is kept in
/// sync by `categoryColorsProvider`, which loads it at startup and updates it on
/// every recolour. Consumers that want to rebuild the moment a colour changes also
/// `ref.watch(categoryColorsProvider)`; the value they render still comes through
/// [slotFor].
class CategoryColors {
  const CategoryColors._();

  static final Map<String, CategoryPalette> _overrides = {};

  /// The resolved slot for [categoryId]: the user override if set, else the
  /// deterministic default.
  static CategoryPalette slotFor(String categoryId) =>
      _overrides[categoryId] ?? CategoryPalette.forId(categoryId);

  /// The raw override for [categoryId], or null when it falls back to the default.
  static CategoryPalette? overrideFor(String categoryId) => _overrides[categoryId];

  /// Replace the whole override map (called when the store loads).
  static void setAll(Map<String, CategoryPalette> overrides) {
    _overrides
      ..clear()
      ..addAll(overrides);
  }

  /// Set or clear a single category's override (called on recolour).
  static void setOne(String categoryId, CategoryPalette? slot) {
    if (slot == null) {
      _overrides.remove(categoryId);
    } else {
      _overrides[categoryId] = slot;
    }
  }
}

import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/auth/auth_controller.dart';
import '../data/categories_repository.dart';
import '../data/outbox/category_outbox.dart';
import '../domain/category.dart';

/// Thrown by the controller's optimistic mutations when a name would collide —
/// the client-side mirror of Money ADR-0033's uniqueness rule (case-insensitive,
/// trim-normalised, spanning active + archived + system names). The server stays
/// authoritative; this just gives an inline error before the outbox round-trips.
class CategoryNameConflict implements Exception {
  const CategoryNameConflict(this.name);
  final String name;
  @override
  String toString() => 'A category named "$name" already exists.';
}

/// The managed category overlay (ADR-0024) for the current user — system built-ins
/// plus the user's own, **including archived** (Money ADR-0033). Source of truth
/// for the management screen (Wallet ADR-0008); the picker reads the active-only
/// view via [categoriesProvider].
///
/// Mutations are optimistic: the local list updates immediately and the write is
/// queued on the outbox (`CategoryOutbox`), which the drainer replays. Colour is
/// handled separately (device-local, `categoryColorsProvider`).
///
/// Auth-gated: fetching while signed out would only 401, so an unauthenticated
/// session yields an empty list; signing in re-fetches.
class CategoriesController extends AsyncNotifier<List<Category>> {
  @override
  Future<List<Category>> build() async {
    final auth = ref.watch(authStateProvider).value;
    if (auth == null || !auth.isAuthenticated) return const <Category>[];
    return ref.watch(categoriesRepositoryProvider).fetch(includeArchived: true);
  }

  List<Category> get _current => state.value ?? const <Category>[];

  bool _isNameTaken(String name, {String? excludeId}) {
    final normalized = name.trim().toLowerCase();
    return _current.any(
      (x) => x.id != excludeId && x.name.trim().toLowerCase() == normalized,
    );
  }

  /// Client mirror of the uniqueness rule, for inline dialog validation. A blank
  /// name is not "available" (the server requires a name).
  bool nameAvailable(String name, {String? excludeId}) =>
      name.trim().isNotEmpty && !_isNameTaken(name, excludeId: excludeId);

  /// Create a user category. Throws [CategoryNameConflict] if the name is taken.
  Future<void> create(String name) async {
    final trimmed = name.trim();
    if (_isNameTaken(trimmed)) throw CategoryNameConflict(trimmed);

    final id = _uuidV4();
    state = AsyncData([
      ..._current,
      Category(id: id, name: trimmed, isSystem: false),
    ]);
    await ref.read(categoryOutboxProvider).create(id: id, name: trimmed);
  }

  /// Rename a user category. Throws [CategoryNameConflict] if the name is taken by
  /// another category (archived included).
  Future<void> rename(String id, String name) async {
    final trimmed = name.trim();
    if (_isNameTaken(trimmed, excludeId: id)) throw CategoryNameConflict(trimmed);

    state = AsyncData([
      for (final c in _current) c.id == id ? c.copyWith(name: trimmed) : c,
    ]);
    await ref.read(categoryOutboxProvider).rename(id: id, name: trimmed);
  }

  Future<void> archive(String id) async {
    state = AsyncData([
      for (final c in _current) c.id == id ? c.copyWith(archived: true) : c,
    ]);
    await ref.read(categoryOutboxProvider).archive(id);
  }

  Future<void> unarchive(String id) async {
    state = AsyncData([
      for (final c in _current) c.id == id ? c.copyWith(archived: false) : c,
    ]);
    await ref.read(categoryOutboxProvider).unarchive(id);
  }
}

final categoriesControllerProvider =
    AsyncNotifierProvider<CategoriesController, List<Category>>(
  CategoriesController.new,
);

/// The active-only overlay for the add-entry picker and other category pickers —
/// the same single source ([categoriesControllerProvider]) with archived filtered
/// out (Wallet ADR-0008). Kept as `categoriesProvider` so existing pickers read it
/// unchanged.
final categoriesProvider = Provider<AsyncValue<List<Category>>>((ref) {
  return ref.watch(categoriesControllerProvider).whenData(
        (all) => [for (final c in all) if (!c.archived) c],
      );
});

String _uuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int b) => b.toRadixString(16).padLeft(2, '0');
  final h = bytes.map(hex).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}'
      '-${h.substring(16, 20)}-${h.substring(20)}';
}

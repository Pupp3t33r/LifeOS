import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/auth/auth_controller.dart';
import '../data/categories_repository.dart';
import '../domain/category.dart';

/// The managed category overlay (ADR-0024) for the current user — system built-ins
/// plus any user categories. Read it with `ref.watch(categoriesProvider)` wherever
/// a category picker is needed (e.g. the add-expense sheet).
///
/// Retained for the session: this is a plain, non-autoDispose [FutureProvider], so
/// once resolved it holds its value for the app's lifetime and the fetch runs once.
/// There is no on-device cache yet — a fresh launch re-fetches.
///
/// Gated on auth like `preferencesProvider`: fetching while signed out would only
/// 401, so an unauthenticated session yields an empty list; signing in re-fetches.
final categoriesProvider = FutureProvider<List<Category>>((ref) {
  final auth = ref.watch(authStateProvider).value;
  if (auth == null || !auth.isAuthenticated) {
    return Future.value(const <Category>[]);
  }
  return ref.watch(categoriesRepositoryProvider).fetch();
});

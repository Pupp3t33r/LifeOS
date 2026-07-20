import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/auth/auth_controller.dart';
import '../data/fx_rates_repository.dart';
import '../domain/fx_rate.dart';

/// The applicable latest rate for each currency pair — the raw `/fx-rates/latest`
/// set collapsed by source precedence (ADR-0015: Belarusbank preferred,
/// Frankfurter fallback), sorted for display in the Rates view. Powers the
/// Settings → Exchange rates panel that makes every conversion traceable.
///
/// Gated on auth: fetching while signed out would only 401, so an unauthenticated
/// session yields an empty list. Watching auth also re-fetches once the user
/// signs in. Invalidate to force a refresh.
final latestFxRatesProvider = FutureProvider<List<FxRate>>((ref) async {
  final auth = ref.watch(authStateProvider).value;
  if (auth == null || !auth.isAuthenticated) return const [];

  final all = await ref.watch(fxRatesRepositoryProvider).fetchLatest();

  // Keep one row per pair — the highest-precedence source that published it.
  final byPair = <String, FxRate>{};
  for (final rate in all) {
    final key = '${rate.base}/${rate.quote}';
    final existing = byPair[key];
    if (existing == null || rate.source.precedence < existing.source.precedence) {
      byPair[key] = rate;
    }
  }

  return byPair.values.toList()
    ..sort((a, b) {
      final byBase = a.base.compareTo(b.base);
      return byBase != 0 ? byBase : a.quote.compareTo(b.quote);
    });
});

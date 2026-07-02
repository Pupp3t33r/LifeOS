import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/month_period.dart';
import 'period_flows_providers.dart';
import 'preferences_providers.dart';

/// The **active** period — the one containing today under the user's month-start-day
/// (ADR-0013/0023). This is where the cockpit lands on every launch; it's derived, not
/// stored (the Money service treats "active" the same way). Recomputed from `now` at
/// build, matching the rest of the cockpit.
final activePeriodProvider = Provider<PeriodKey>((ref) {
  final startDay = ref.watch(preferencesProvider).value?.monthStartDay ?? 1;
  final p = containingPeriod(DateTime.now(), startDay);
  return (year: p.year, month: p.month);
});

/// The period the user is currently browsing, or null while they're on the active one
/// (ADR-0002 period switcher). Null — not a copy of the active key — is the default so
/// the cockpit **always reopens on the active period**: nothing is persisted across
/// launches, and the resolved [viewedPeriodProvider] tracks `active` until the user
/// steps away with the chevrons.
class SelectedPeriodNotifier extends Notifier<PeriodKey?> {
  @override
  PeriodKey? build() => null;

  /// Step to the next/previous calendar period from wherever the user is now.
  void next() => _shift(1);
  void previous() => _shift(-1);

  /// Snap back to the active period (clears the manual selection).
  void jumpToActive() => state = null;

  void _shift(int delta) {
    final PeriodKey current = state ?? ref.read(activePeriodProvider);
    final zeroBased = current.year * 12 + (current.month - 1) + delta;
    state = (year: zeroBased ~/ 12, month: zeroBased % 12 + 1);
  }
}

final selectedPeriodProvider =
    NotifierProvider<SelectedPeriodNotifier, PeriodKey?>(SelectedPeriodNotifier.new);

/// The period actually on screen: the manual selection if the user has stepped away,
/// else the active period. Feed this to the per-period providers.
final viewedPeriodProvider = Provider<PeriodKey>((ref) {
  return ref.watch(selectedPeriodProvider) ?? ref.watch(activePeriodProvider);
});

/// Where the viewed period sits relative to today. Date-derived only — the `/months`
/// read-model carries no close flag, so the client can't tell a closed period from a
/// past-open one; the server stays the backstop for "closed = read-only" (ADR-0023).
enum PeriodStatus { past, active, future }

final viewedPeriodStatusProvider = Provider<PeriodStatus>((ref) {
  final active = ref.watch(activePeriodProvider);
  final viewed = ref.watch(viewedPeriodProvider);
  final a = active.year * 12 + active.month;
  final v = viewed.year * 12 + viewed.month;
  if (v < a) return PeriodStatus.past;
  if (v > a) return PeriodStatus.future;
  return PeriodStatus.active;
});

import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/auth/auth_controller.dart';
import '../../../app/data/app_database.dart';
import '../../../app/data/operation_status.dart';
import '../../../app/data/outbox_repository.dart';
import '../data/period_flows_repository.dart';
import '../domain/money.dart';
import '../domain/period_flows.dart';

/// A `(year, month)` accounting period — the key for the per-period providers.
typedef PeriodKey = ({int year, int month});

/// A queued-but-unconfirmed flow entry from the outbox, tagged with the period it
/// will land in (parsed from the operation's path).
typedef PendingFlow = ({int year, int month, FlowEntry entry});

/// The cockpit's period view: the server-confirmed cache for [key] **merged** with
/// any optimistic outbox entries for the same period (deduped by id once the cache
/// catches up). The cache renders instantly; a background revalidate keeps it fresh.
///
/// Auth-gated like `categoriesProvider` — signed out, the cache is empty and no
/// fetch is attempted.
final periodFlowsProvider =
    Provider.family<AsyncValue<List<FlowEntry>>, PeriodKey>((ref, key) {
  final cached = ref.watch(_cachedPeriodFlowsProvider(key));
  final pending = ref.watch(pendingFlowEntriesProvider).value ?? const <PendingFlow>[];

  return cached.whenData((entries) {
    final confirmedIds = entries.map((x) => x.entryId).toSet();
    final overlay = pending
        .where((x) =>
            x.year == key.year &&
            x.month == key.month &&
            !confirmedIds.contains(x.entry.entryId))
        .map((x) => x.entry);
    final merged = [...overlay, ...entries]
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return merged;
  });
});

/// Net total per currency across the period's entries (Σ of signed totals). Pending
/// entries are included so the figure matches what the list shows.
final periodTotalsProvider =
    Provider.family<List<Money>, PeriodKey>((ref, key) {
  final entries = ref.watch(periodFlowsProvider(key)).value ?? const <FlowEntry>[];
  final byCurrency = <String, num>{};
  for (final entry in entries) {
    byCurrency.update(
      entry.total.currency,
      (sum) => sum + entry.total.amount,
      ifAbsent: () => entry.total.amount,
    );
  }
  final currencies = byCurrency.keys.toList()..sort();
  return [for (final c in currencies) Money(amount: byCurrency[c]!, currency: c)];
});

/// When the period was last successfully revalidated against the server (null until
/// the first refresh) — the cockpit shows it as a muted "Updated …" line so the
/// staleness of this never-evicted cache stays honest.
final periodSyncedAtProvider =
    StreamProvider.family<DateTime?, PeriodKey>((ref, key) {
  return ref.watch(periodFlowsRepositoryProvider).watchSyncedAt(key.year, key.month);
});

/// Reactive cache for one period. Emits the cached rows immediately and kicks a
/// background revalidate; re-watching the outbox means a queued entry **syncing**
/// (dropping out of the pending set) triggers a fresh fetch that pulls its confirmed
/// twin into the cache, so the optimistic overlay can be deduped without a flicker.
final _cachedPeriodFlowsProvider =
    StreamProvider.family<List<FlowEntry>, PeriodKey>((ref, key) {
  final repo = ref.watch(periodFlowsRepositoryProvider);
  final auth = ref.watch(authStateProvider).value;

  if (auth != null && auth.isAuthenticated) {
    ref.watch(pendingFlowEntriesProvider); // revalidate when the outbox changes
    unawaited(repo.refresh(key.year, key.month));
  }

  return repo.watch(key.year, key.month);
});

/// Optimistic flow entries still in the outbox (queued or syncing) — decoded from
/// the durable `record_flow` operations so a just-added (or offline) entry shows in
/// the cockpit before the server confirms it. Marked [FlowEntry.pending].
final pendingFlowEntriesProvider = StreamProvider<List<PendingFlow>>((ref) {
  final outbox = ref.watch(outboxRepositoryProvider);
  return outbox.watchPending().map((ops) => ops
      .where((x) => x.kind == 'record_flow' && x.status != OperationStatus.failed)
      .map(_decode)
      .whereType<PendingFlow>()
      .toList());
});

final _periodPath = RegExp(r'/months/(\d+)/(\d+)/transactions');

/// Decode a `record_flow` outbox row (request shape: positive magnitudes + a
/// direction) into the same signed [FlowEntry] the cockpit renders. Returns null if
/// the row can't be parsed — a malformed op should never crash the cockpit.
PendingFlow? _decode(PendingOperation op) {
  try {
    final match = _periodPath.firstMatch(op.path);
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);

    final payload = jsonDecode(op.payload) as Map<String, dynamic>;
    final isIncome = payload['direction'] == 'in';
    final sign = isIncome ? 1 : -1;
    final currency = payload['currency'] as String;

    final lines = [
      for (final raw in payload['lines'] as List<dynamic>)
        FlowLine(
          amount: Money(
            amount: sign * (raw['amount'] as num),
            currency: currency,
          ),
          categoryId: raw['categoryId'] as String?,
          description: raw['description'] as String?,
        ),
    ];
    final total = lines.fold<num>(0, (sum, line) => sum + line.amount.amount);

    final entry = FlowEntry(
      entryId: op.id,
      isIncome: isIncome,
      lines: lines,
      total: Money(amount: total, currency: currency),
      occurredAt: DateTime.parse(payload['occurredAt'] as String),
      description: payload['description'] as String?,
      pending: true,
    );
    return (year: year, month: month, entry: entry);
  } catch (_) {
    return null;
  }
}

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/data/app_database.dart';
import '../domain/money.dart';
import '../domain/period_flows.dart';
import 'money_api.dart';

/// Read-through cache for the period flow ledger (ADR-0016): fetches a period from
/// the Money service and mirrors it into the local [CachedFlowEntries] table, so the
/// cockpit renders from the cache offline and the network only ever revalidates.
///
/// Hand-rolled over [Dio] like the other Money repositories; the generated OpenAPI
/// dart-dio client (apps/wallet/AGENTS.md) supersedes the HTTP half when it lands.
class PeriodFlowsRepository {
  PeriodFlowsRepository(this._dio, this._db);

  final Dio _dio;
  final AppDatabase _db;

  /// Fetch one period's flow ledger from the server (no caching side effect).
  Future<PeriodFlows> fetch(int year, int month) async {
    final res = await _dio.get<Map<String, dynamic>>('/months/$year/$month');
    return PeriodFlows.fromJson(res.data!);
  }

  /// Revalidate: fetch the period and rewrite its cached rows, stamping the period's
  /// freshness. Network failures are swallowed — the existing cache (and its old
  /// freshness stamp) is left intact for offline reads and the next refresh retries.
  Future<void> refresh(int year, int month) async {
    try {
      final flows = await fetch(year, month);
      await _replacePeriod(year, month, flows.entries, DateTime.now());
    } on DioException {
      // Offline / transient: keep what we have.
    }
  }

  /// Reactive cached entries for one period, newest [FlowEntry.occurredAt] first.
  Stream<List<FlowEntry>> watch(int year, int month) {
    return (_db.select(_db.cachedFlowEntries)
          ..where((x) => x.year.equals(year) & x.month.equals(month))
          ..orderBy([
            (x) => OrderingTerm.desc(x.occurredAt),
            (x) => OrderingTerm.desc(x.recordedAt),
          ]))
        .watch()
        .map((rows) => rows.map(_fromRow).toList());
  }

  /// Reactive last-synced time for one period — null until its first successful
  /// refresh. Drives the cockpit's "Updated …" freshness line.
  Stream<DateTime?> watchSyncedAt(int year, int month) {
    return (_db.select(_db.cachedPeriodMeta)
          ..where((x) => x.year.equals(year) & x.month.equals(month)))
        .watchSingleOrNull()
        .map((row) => row?.lastSyncedAt);
  }

  /// Replace a period's cached rows in one transaction (delete-then-insert) and
  /// stamp its freshness. The server response is authoritative for the period, so a
  /// wholesale swap keeps the cache exactly in step — including removals (a reverted
  /// entry simply isn't re-inserted). Only the refreshed period is touched; every
  /// other period stays cached (see [CachedFlowEntries] — keep-everything retention).
  Future<void> _replacePeriod(
    int year,
    int month,
    List<FlowEntry> entries,
    DateTime syncedAt,
  ) async {
    await _db.transaction(() async {
      await (_db.delete(_db.cachedFlowEntries)
            ..where((x) => x.year.equals(year) & x.month.equals(month)))
          .go();
      for (final entry in entries) {
        await _db.into(_db.cachedFlowEntries).insert(_toRow(year, month, entry));
      }
      await _db.into(_db.cachedPeriodMeta).insertOnConflictUpdate(
            CachedPeriodMetaCompanion.insert(
              year: year,
              month: month,
              lastSyncedAt: syncedAt,
            ),
          );
    });
  }

  CachedFlowEntriesCompanion _toRow(int year, int month, FlowEntry entry) {
    return CachedFlowEntriesCompanion.insert(
      entryId: entry.entryId,
      year: year,
      month: month,
      direction: entry.isIncome ? 'in' : 'out',
      description: Value(entry.description),
      totalAmount: entry.total.amount.toDouble(),
      totalCurrency: entry.total.currency,
      linesJson: jsonEncode([
        for (final line in entry.lines)
          {
            'amount': {'amount': line.amount.amount, 'currency': line.amount.currency},
            'categoryId': line.categoryId,
            'description': line.description,
          },
      ]),
      occurredAt: entry.occurredAt,
      recordedAt: entry.recordedAt ?? entry.occurredAt,
    );
  }

  FlowEntry _fromRow(CachedFlowEntry row) {
    final lines = (jsonDecode(row.linesJson) as List<dynamic>)
        .map((x) => FlowLine.fromJson(x as Map<String, dynamic>))
        .toList();
    return FlowEntry(
      entryId: row.entryId,
      isIncome: row.direction == 'in',
      lines: lines,
      total: Money(amount: row.totalAmount, currency: row.totalCurrency),
      occurredAt: row.occurredAt,
      recordedAt: row.recordedAt,
      description: row.description,
    );
  }
}

final periodFlowsRepositoryProvider = Provider<PeriodFlowsRepository>(
  (ref) => PeriodFlowsRepository(
    ref.watch(moneyApiProvider),
    ref.watch(appDatabaseProvider),
  ),
);

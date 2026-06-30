import 'package:drift/drift.dart';

/// Per-period freshness marker for the flow cache: when we last successfully
/// revalidated `(year, month)` against the server. One row per period, upserted on
/// every successful refresh — recorded even when the period has zero entries, so the
/// cockpit can honestly say "checked just now, nothing here" versus "never loaded".
///
/// Separate from [CachedFlowEntries] precisely so an empty period still has a
/// timestamp (it has no entry rows to hang one on).
@DataClassName('PeriodSyncMeta')
class CachedPeriodMeta extends Table {
  @override
  String get tableName => 'cached_period_meta';

  IntColumn get year => integer()();
  IntColumn get month => integer()();

  /// Wall-clock time of the last successful server revalidation for this period.
  DateTimeColumn get lastSyncedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {year, month};
}

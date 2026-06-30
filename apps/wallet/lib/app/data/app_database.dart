import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'cached_flow_entries.dart';
import 'cached_period_meta.dart';
import 'operation_status.dart';
import 'pending_operations.dart';

part 'app_database.g.dart';

/// The app's single local SQLite database, opened through `drift_flutter` so one
/// call site serves every platform: native via `sqlite3_flutter_libs`, web via
/// the bundled WASM build (`web/sqlite3.wasm` + `web/drift_worker.js`). The
/// engine differs underneath but our code does not branch on platform.
///
/// Holds the [PendingOperations] outbox (the write half), [CachedFlowEntries] (the
/// read-model cache — "fetch & cache") and [CachedPeriodMeta] (per-period freshness).
/// More cached read-models join here as the cockpit grows; each addition bumps
/// [schemaVersion] with a migration step.
@DriftDatabase(tables: [PendingOperations, CachedFlowEntries, CachedPeriodMeta])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());

  /// Seam for tests, which pass an in-memory executor (`NativeDatabase.memory()`).
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          // v1 → v2: add the period flow read-model cache and its freshness markers.
          // Both are pure caches, so creating them empty is safe — the next refresh
          // repopulates them.
          if (from < 2) {
            await m.createTable(cachedFlowEntries);
            await m.createTable(cachedPeriodMeta);
          }
        },
      );

  static QueryExecutor _open() {
    return driftDatabase(
      name: 'wallet',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }
}

/// App-lifetime handle to the local database. Closed when the provider scope is
/// disposed.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

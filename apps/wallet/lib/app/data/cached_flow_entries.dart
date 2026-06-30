import 'package:drift/drift.dart';

/// Local cache of the period flow read-model (the "fetch & cache" half — see
/// apps/wallet/AGENTS.md, "Data and sync"). One row per server-confirmed flow
/// entry; the Money service stays the source of truth, this is a read-through cache
/// the cockpit renders from offline and refreshes in the background.
///
/// Deliberately denormalised: lines are stored as a JSON blob ([linesJson]) rather
/// than a child table — this cache is read whole per period and never queried by
/// line. [year]/[month] index the period the entry belongs to (its server bucket,
/// ADR-0016). Optimistic, not-yet-synced entries are NOT stored here; they come from
/// the outbox overlay and are merged at read time.
///
/// **Retention: keep everything, no eviction (deliberate).** Every period ever
/// fetched stays cached for offline history. This is an accepted trade-off, not a
/// leak: a flow entry is a few hundred bytes (a heavy year is well under a MB), and
/// past periods are immutable once closed (ADR-0007/0023), so stale cached history
/// can't drift out of sync. Revisit only if multi-year accounts make the table large.
class CachedFlowEntries extends Table {
  @override
  String get tableName => 'cached_flow_entries';

  /// Server entry id (a Guid, as text); also the idempotency key (ADR-0003). The
  /// outbox overlay dedups against this, so a confirmed entry replaces its pending
  /// twin cleanly.
  TextColumn get entryId => text()();

  /// The accounting period this entry was bucketed into.
  IntColumn get year => integer()();
  IntColumn get month => integer()();

  /// `'in'` (income) or `'out'` (expense) — the entry direction.
  TextColumn get direction => text()();

  /// Optional entry-level note.
  TextColumn get description => text().nullable()();

  /// Signed entry total (Σ of line amounts) and its single currency (ADR-0019).
  RealColumn get totalAmount => real()();
  TextColumn get totalCurrency => text()();

  /// The entry's lines, as the JSON array the server returned.
  TextColumn get linesJson => text()();

  /// When the entry actually happened, and when the server recorded it. Newest
  /// [occurredAt] first is the cockpit's display order.
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get recordedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {entryId};
}

import 'money.dart';

/// Dart mirror of the Money service's `PeriodFlowsResponse` — the flow ledger for
/// one accounting period (ADR-0016): the recorded [entries], newest first, plus the
/// per-currency net [totals]. This is the flow read-model only, not the composed
/// MonthProjection (ADR-0007); there is no projected/target/actual-savings here yet.
class PeriodFlows {
  const PeriodFlows({
    required this.year,
    required this.month,
    required this.entries,
    required this.totals,
  });

  final int year;
  final int month;
  final List<FlowEntry> entries;
  final List<Money> totals;

  factory PeriodFlows.fromJson(Map<String, dynamic> json) => PeriodFlows(
        year: json['year'] as int,
        month: json['month'] as int,
        entries: (json['entries'] as List<dynamic>)
            .map((x) => FlowEntry.fromJson(x as Map<String, dynamic>))
            .toList(),
        totals: (json['totals'] as List<dynamic>)
            .map((x) => _money(x as Map<String, dynamic>))
            .toList(),
      );
}

/// One recorded flow entry. [total] and each line's amount are **signed** (negative
/// = out, positive = in), so the entry reads as a plain Σ (ADR-0026); [isIncome]
/// is the direction surfaced for the UI. [pending] is true while the entry is still
/// in the local outbox (queued/syncing), not yet confirmed by the server — the
/// cockpit shows it with a "syncing" affordance and it carries no [recordedAt].
class FlowEntry {
  const FlowEntry({
    required this.entryId,
    required this.isIncome,
    required this.lines,
    required this.total,
    required this.occurredAt,
    this.recordedAt,
    this.description,
    this.pending = false,
  });

  final String entryId;
  final bool isIncome;
  final List<FlowLine> lines;
  final Money total;
  final DateTime occurredAt;
  final DateTime? recordedAt;
  final String? description;
  final bool pending;

  factory FlowEntry.fromJson(Map<String, dynamic> json) => FlowEntry(
        entryId: json['entryId'] as String,
        isIncome: json['direction'] == 'in',
        lines: (json['lines'] as List<dynamic>)
            .map((x) => FlowLine.fromJson(x as Map<String, dynamic>))
            .toList(),
        total: _money(json['total'] as Map<String, dynamic>),
        occurredAt: DateTime.parse(json['occurredAt'] as String),
        recordedAt: DateTime.parse(json['recordedAt'] as String),
        description: json['description'] as String?,
      );
}

/// One line of an entry: a signed [amount], an optional budgeting [categoryId]
/// (ADR-0024; null = uncategorised) and an optional [description].
class FlowLine {
  const FlowLine({required this.amount, this.categoryId, this.description});

  final Money amount;
  final String? categoryId;
  final String? description;

  factory FlowLine.fromJson(Map<String, dynamic> json) => FlowLine(
        amount: _money(json['amount'] as Map<String, dynamic>),
        categoryId: json['categoryId'] as String?,
        description: json['description'] as String?,
      );
}

Money _money(Map<String, dynamic> json) => Money(
      amount: json['amount'] as num,
      currency: json['currency'] as String,
    );

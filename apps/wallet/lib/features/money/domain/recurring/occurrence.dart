import '../money.dart';
import 'date_only.dart';
import 'recurring_line.dart';

/// How an occurrence stands against its period's back-references (ADR-0017).
enum OccurrenceStatus { projected, paid, skipped }

/// Dart mirror of the Money service's `OccurrenceResponse` — one computed/listed
/// occurrence in a window. [occurrenceRef] is the stable key used to confirm/skip:
/// the ISO due date for a Live occurrence, or the schedule line id for a Materialized
/// one. [expectedAmount] is the planned figure; when [status] is [OccurrenceStatus.paid],
/// [actualAmount]/[paidOn] carry the real ones (which may differ for a Live item).
/// [lines] is the breakdown a confirm records — the estimate for Live, the proportional
/// slice for a plan payment.
class Occurrence {
  const Occurrence({
    required this.dueDate,
    required this.occurrenceRef,
    required this.expectedAmount,
    required this.lines,
    required this.status,
    this.actualAmount,
    this.paidOn,
  });

  final DateTime dueDate;
  final String occurrenceRef;
  final Money expectedAmount;
  final List<RecurringLine> lines;
  final OccurrenceStatus status;
  final Money? actualAmount;
  final DateTime? paidOn;

  factory Occurrence.fromJson(Map<String, dynamic> json) {
    Money money(Map<String, dynamic> m) =>
        Money(amount: m['amount'] as num, currency: m['currency'] as String);
    final actual = json['actualAmount'] as Map<String, dynamic>?;
    final paidOn = json['paidOn'] as String?;
    return Occurrence(
      dueDate: parseDateOnly(json['dueDate'] as String),
      occurrenceRef: json['occurrenceRef'] as String,
      expectedAmount: money(json['expectedAmount'] as Map<String, dynamic>),
      lines: [
        for (final x in json['lines'] as List<dynamic>)
          RecurringLine.fromJson(x as Map<String, dynamic>),
      ],
      status: switch (json['status']) {
        'paid' => OccurrenceStatus.paid,
        'skipped' => OccurrenceStatus.skipped,
        _ => OccurrenceStatus.projected,
      },
      actualAmount: actual == null ? null : money(actual),
      paidOn: paidOn == null ? null : parseDateOnly(paidOn),
    );
  }
}

import 'date_only.dart';

/// Dart mirror of the Money service's `RecurrenceRule` (ADR-0017) — the `kind`-
/// discriminated union that drives a **Live** schedule's occurrences. Kept
/// structurally identical to the server's sealed records (`daily` / `weekly` /
/// `monthly` / `yearly`) so one rule means the same thing on both sides.
///
/// [start] fixes the phase of the cadence and [end] bounds it. Dates are calendar
/// dates (midnight-local [DateTime]s), never instants. Serialized with the same
/// `kind` discriminator System.Text.Json writes; enums cross the wire as the .NET
/// `DayOfWeek` integer (Sunday = 0 … Saturday = 6).
sealed class RecurrenceRule {
  const RecurrenceRule({required this.start, required this.end});

  final DateTime start;
  final RecurrenceEnd end;

  Map<String, dynamic> toJson();

  static RecurrenceRule? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final start = parseDateOnly(json['start'] as String);
    final end = RecurrenceEnd.fromJson(json['end'] as Map<String, dynamic>);
    return switch (json['kind']) {
      'daily' => DailyRule(start: start, end: end, intervalDays: json['intervalDays'] as int),
      'weekly' => WeeklyRule(
          start: start,
          end: end,
          intervalWeeks: json['intervalWeeks'] as int,
          weekdays: [for (final x in json['weekdays'] as List<dynamic>) x as int],
        ),
      'monthly' => MonthlyRule(
          start: start,
          end: end,
          intervalMonths: json['intervalMonths'] as int,
          days: [
            for (final x in json['days'] as List<dynamic>)
              MonthDayAnchor.fromJson(x as Map<String, dynamic>),
          ],
        ),
      'yearly' => YearlyRule(
          start: start,
          end: end,
          intervalYears: json['intervalYears'] as int,
          dates: [
            for (final x in json['dates'] as List<dynamic>)
              AnnualDate(month: x['month'] as int, day: x['day'] as int),
          ],
        ),
      _ => null,
    };
  }
}

/// Every [intervalDays] days from [start].
class DailyRule extends RecurrenceRule {
  const DailyRule({required super.start, required super.end, required this.intervalDays});

  final int intervalDays;

  @override
  Map<String, dynamic> toJson() => {
        'kind': 'daily',
        'start': dateOnlyString(start),
        'end': end.toJson(),
        'intervalDays': intervalDays,
      };
}

/// On the given [weekdays] (`DayOfWeek` ints), every [intervalWeeks] weeks.
class WeeklyRule extends RecurrenceRule {
  const WeeklyRule({
    required super.start,
    required super.end,
    required this.intervalWeeks,
    required this.weekdays,
  });

  final int intervalWeeks;
  final List<int> weekdays;

  @override
  Map<String, dynamic> toJson() => {
        'kind': 'weekly',
        'start': dateOnlyString(start),
        'end': end.toJson(),
        'intervalWeeks': intervalWeeks,
        'weekdays': weekdays,
      };
}

/// On the given [days] anchors, every [intervalMonths] months.
class MonthlyRule extends RecurrenceRule {
  const MonthlyRule({
    required super.start,
    required super.end,
    required this.intervalMonths,
    required this.days,
  });

  final int intervalMonths;
  final List<MonthDayAnchor> days;

  @override
  Map<String, dynamic> toJson() => {
        'kind': 'monthly',
        'start': dateOnlyString(start),
        'end': end.toJson(),
        'intervalMonths': intervalMonths,
        'days': [for (final x in days) x.toJson()],
      };
}

/// On the given [dates], every [intervalYears] years.
class YearlyRule extends RecurrenceRule {
  const YearlyRule({
    required super.start,
    required super.end,
    required this.intervalYears,
    required this.dates,
  });

  final int intervalYears;
  final List<AnnualDate> dates;

  @override
  Map<String, dynamic> toJson() => {
        'kind': 'yearly',
        'start': dateOnlyString(start),
        'end': end.toJson(),
        'intervalYears': intervalYears,
        'dates': [for (final x in dates) x.toJson()],
      };
}

/// When a recurrence stops (ADR-0017): `never` / `onDate` / `afterCount`. The
/// **Ongoing** UI only ever offers `never` and `onDate` — a countable end is a
/// Payment plan — but [EndsAfter] is mirrored for completeness.
sealed class RecurrenceEnd {
  const RecurrenceEnd();

  Map<String, dynamic> toJson();

  static RecurrenceEnd fromJson(Map<String, dynamic> json) => switch (json['kind']) {
        'onDate' => EndsOnDate(date: parseDateOnly(json['date'] as String)),
        'afterCount' => EndsAfter(count: json['count'] as int),
        _ => const NeverEnds(),
      };
}

/// An open-ended recurrence — salary, rent, a subscription.
class NeverEnds extends RecurrenceEnd {
  const NeverEnds();

  @override
  Map<String, dynamic> toJson() => {'kind': 'never'};
}

/// Stops after a fixed date (inclusive).
class EndsOnDate extends RecurrenceEnd {
  const EndsOnDate({required this.date});

  final DateTime date;

  @override
  Map<String, dynamic> toJson() => {'kind': 'onDate', 'date': dateOnlyString(date)};
}

/// Stops after a fixed [count] of occurrences.
class EndsAfter extends RecurrenceEnd {
  const EndsAfter({required this.count});

  final int count;

  @override
  Map<String, dynamic> toJson() => {'kind': 'afterCount', 'count': count};
}

/// Which day of a month a [MonthlyRule] fires on: a fixed day or the last day.
sealed class MonthDayAnchor {
  const MonthDayAnchor();

  Map<String, dynamic> toJson();

  static MonthDayAnchor fromJson(Map<String, dynamic> json) => switch (json['kind']) {
        'lastDay' => const LastDayOfMonth(),
        _ => OnDayOfMonth(day: json['day'] as int),
      };
}

/// The Nth day of the month (1–31); clamps to the last day in shorter months.
class OnDayOfMonth extends MonthDayAnchor {
  const OnDayOfMonth({required this.day});

  final int day;

  @override
  Map<String, dynamic> toJson() => {'kind': 'dayOfMonth', 'day': day};
}

/// The last day of whichever month the occurrence falls in.
class LastDayOfMonth extends MonthDayAnchor {
  const LastDayOfMonth();

  @override
  Map<String, dynamic> toJson() => {'kind': 'lastDay'};
}

/// A month-and-day within a year for a [YearlyRule]; [day] clamps to the month's length.
class AnnualDate {
  const AnnualDate({required this.month, required this.day});

  final int month;
  final int day;

  Map<String, dynamic> toJson() => {'month': month, 'day': day};
}

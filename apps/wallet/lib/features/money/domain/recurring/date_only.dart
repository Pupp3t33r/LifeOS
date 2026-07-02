/// Wire helpers for the Money service's `DateOnly` — serialized by System.Text.Json
/// as an ISO `yyyy-MM-dd` string (no time, no zone). The recurring feature deals in
/// due dates and rule anchors that are calendar dates, never instants, so we keep
/// them as midnight-local [DateTime]s and cross the wire through these two functions.
library;

/// Format a calendar date as the `yyyy-MM-dd` the Money service expects.
String dateOnlyString(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year.toString().padLeft(4, '0')}-$month-$day';
}

/// Parse a `yyyy-MM-dd` date from the Money service into a midnight-local [DateTime].
DateTime parseDateOnly(String value) {
  final parts = value.split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

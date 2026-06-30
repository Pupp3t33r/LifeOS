/// Maps a date to the `(year, month)` accounting period it falls in — a Dart mirror
/// of the Money service's `MonthPeriod.ContainingPeriod` (ADR-0013), so the client
/// addresses the same period the server would bucket the actual into.
///
/// A period `(Y, M)` starts on day `min(monthStartDay, daysInMonth(Y, M))`. A date
/// on or after its own calendar month's anchor belongs to that month's period;
/// an earlier date belongs to the previous calendar month's period. `monthStartDay`
/// of 1 degenerates to calendar months.
({int year, int month}) containingPeriod(DateTime date, int monthStartDay) {
  final daysInMonth = DateTime(date.year, date.month + 1, 0).day;
  final anchorDay = monthStartDay < daysInMonth ? monthStartDay : daysInMonth;
  if (date.day >= anchorDay) {
    return (year: date.year, month: date.month);
  }
  return date.month == 1
      ? (year: date.year - 1, month: 12)
      : (year: date.year, month: date.month - 1);
}

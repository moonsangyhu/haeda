/// Returns the effective "today" date given the current time and a cutoff hour.
///
/// If [now] is before [cutoffHour] o'clock (e.g. 01:30 with cutoff=2),
/// the previous calendar day is returned, so late-night verifications
/// count toward the previous day's mission.
///
/// Examples:
///   effectiveToday(DateTime(2026,3,9,1,59), 2) → DateTime(2026,3,8)
///   effectiveToday(DateTime(2026,3,9,2,0),  2) → DateTime(2026,3,9)
///   effectiveToday(DateTime(2026,3,9,0,0),  0) → DateTime(2026,3,9)
DateTime effectiveToday(DateTime now, int cutoffHour) {
  final adjusted = now.subtract(Duration(hours: cutoffHour));
  return DateTime(adjusted.year, adjusted.month, adjusted.day);
}

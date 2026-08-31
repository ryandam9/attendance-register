import 'special_day.dart';

/// Counts the weekdays (Mon–Fri) in the inclusive range [start]..[end].
///
/// The attendance-percentage denominator is built from weekdays only, so this
/// is the single source of truth used by both the home dashboard and the
/// Explain report.
int countWeekdays(DateTime start, DateTime end) {
  var count = 0;
  var current = DateTime(start.year, start.month, start.day);
  final last = DateTime(end.year, end.month, end.day);
  while (!current.isAfter(last)) {
    final wd = current.weekday;
    if (wd != DateTime.saturday && wd != DateTime.sunday) count++;
    current = current.add(const Duration(days: 1));
  }
  return count;
}

/// An itemised breakdown of a reporting period used by the Explain page: every
/// count that feeds the "Return to office" percentage, plus the derived figures
/// (excluded days, eligible working days, the percentage itself).
///
/// The maths mirrors the home dashboard exactly: the denominator is the number
/// of weekdays minus the leave types listed in
/// [excludedFromAttendanceDenominator]; work-from-home and not-attended days
/// stay in the denominator and therefore lower the percentage.
///
/// The period is always the whole reporting window (a full month or year), not
/// the part of it that has elapsed. Dividing by elapsed days only would report
/// 100% after a single office day on the first of the month — a number that
/// says nothing about whether the target will be met.
class AttendanceBreakdown {
  /// Weekdays (Mon–Fri) in the period — every one of them, including weekdays
  /// still to come in a period that is under way.
  final int weekdays;

  /// Weekdays you were recorded at the office (the percentage numerator).
  /// Weekday-only so the numerator and the weekday-built denominator agree —
  /// a Saturday check-in must not inflate the percentage.
  final int officeDays;

  /// Office days that fell on a weekend. Shown for transparency but excluded
  /// from the percentage maths entirely.
  final int weekendOfficeDays;

  /// Count of each special-day type in the period — weekdays only, matching the
  /// denominator's weekday-only rule.
  final Map<DayType, int> specialDayCounts;

  /// Eligible working days left in the period, today included: the weekdays
  /// from today to the period's end, minus the leave already booked in them.
  /// Zero once the period is over — that is what tells the UI the percentage
  /// is final and it should report the outcome instead of asking for office
  /// days that can no longer be recorded.
  final int remainingEligibleDays;

  const AttendanceBreakdown({
    required this.weekdays,
    required this.officeDays,
    required this.specialDayCounts,
    required this.remainingEligibleDays,
    this.weekendOfficeDays = 0,
  });

  int countOf(DayType type) => specialDayCounts[type] ?? 0;

  /// Leave days subtracted from the denominator (holiday, sick, annual, carer's).
  int get excludedDays => excludedFromAttendanceDenominator.fold(
    0,
    (sum, type) => sum + countOf(type),
  );

  /// Weekdays you were expected at the office — the percentage denominator.
  int get eligibleWorkingDays => weekdays - excludedDays;

  /// Return-to-office percentage, or null when there are no eligible working
  /// days to divide by (so the UI can show "—" instead of a divide-by-zero).
  double? get returnToOfficePercentage {
    if (eligibleWorkingDays <= 0) return null;
    return (officeDays / eligibleWorkingDays * 100).clamp(0.0, 100.0);
  }

  /// Office days still needed to reach [target] percent — 0 once it is met.
  int officeDaysToTarget(int target) =>
      ((target / 100 * eligibleWorkingDays).ceil() - officeDays).clamp(0, 9999);

  /// Whether [target] percent is still achievable: reaching it must not need
  /// more office days than there are working days left in the period. A month
  /// that has ended has none left, so an unmet target there is simply missed.
  bool targetReachable(int target) =>
      officeDaysToTarget(target) <= remainingEligibleDays;

  /// True when no eligible working day remains — the period is over, or every
  /// weekday left in it is already booked as leave. The percentage is final.
  bool get isFinal => remainingEligibleDays <= 0;
}

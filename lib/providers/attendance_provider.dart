import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/attendance_breakdown.dart';
import '../models/attendance_record.dart';
import '../models/report_period.dart';
import '../models/special_day.dart';
import '../services/database_service.dart';
import 'settings_provider.dart';

enum CheckInResult { recorded, alreadyRecorded, alreadyRecordedByAuto, specialDayConflict }

class AttendanceState {
  final List<AttendanceRecord> records;
  // Total office days, including weekend check-ins — what the stat cards show.
  final int monthlyCount;
  final int yearlyCount;
  // Office days that fell on a weekday (Mon–Fri) — the percentage numerator.
  // Kept separate from the display counts so a Saturday at the office still
  // shows up as a day, but cannot inflate the weekday-based percentage.
  final int monthlyOfficeWeekdays;
  final int yearlyOfficeWeekdays;
  final int monthlyWeekdays;
  final int yearlyWeekdays;
  // Weekday count of all leave types excluded from the denominator (holiday,
  // sick, annual, carer's) — see excludedFromAttendanceDenominator.
  final int monthlyExcludedCount;
  final int yearlyExcludedCount;
  final bool loading;

  const AttendanceState({
    this.records = const [],
    this.monthlyCount = 0,
    this.yearlyCount = 0,
    this.monthlyOfficeWeekdays = 0,
    this.yearlyOfficeWeekdays = 0,
    this.monthlyWeekdays = 0,
    this.yearlyWeekdays = 0,
    this.monthlyExcludedCount = 0,
    this.yearlyExcludedCount = 0,
    this.loading = false,
  });

  AttendanceState copyWith({
    List<AttendanceRecord>? records,
    int? monthlyCount,
    int? yearlyCount,
    int? monthlyOfficeWeekdays,
    int? yearlyOfficeWeekdays,
    int? monthlyWeekdays,
    int? yearlyWeekdays,
    int? monthlyExcludedCount,
    int? yearlyExcludedCount,
    bool? loading,
  }) {
    return AttendanceState(
      records: records ?? this.records,
      monthlyCount: monthlyCount ?? this.monthlyCount,
      yearlyCount: yearlyCount ?? this.yearlyCount,
      monthlyOfficeWeekdays: monthlyOfficeWeekdays ?? this.monthlyOfficeWeekdays,
      yearlyOfficeWeekdays: yearlyOfficeWeekdays ?? this.yearlyOfficeWeekdays,
      monthlyWeekdays: monthlyWeekdays ?? this.monthlyWeekdays,
      yearlyWeekdays: yearlyWeekdays ?? this.yearlyWeekdays,
      monthlyExcludedCount: monthlyExcludedCount ?? this.monthlyExcludedCount,
      yearlyExcludedCount: yearlyExcludedCount ?? this.yearlyExcludedCount,
      loading: loading ?? this.loading,
    );
  }

  /// The YYYY-MM-DD keys of the loaded month's attendance, for O(1) calendar
  /// lookups (record dates are already stored in that form).
  Set<String> get attendanceDateKeys => records.map((r) => r.date).toSet();

  double? get monthlyPercentage {
    final base = monthlyWeekdays - monthlyExcludedCount;
    if (base <= 0) return null;
    return (monthlyOfficeWeekdays / base * 100).clamp(0.0, 100.0);
  }

  double? get yearlyPercentage {
    final base = yearlyWeekdays - yearlyExcludedCount;
    if (base <= 0) return null;
    return (yearlyOfficeWeekdays / base * 100).clamp(0.0, 100.0);
  }
}

class AttendanceNotifier extends Notifier<AttendanceState> {
  @override
  AttendanceState build() => const AttendanceState();

  Future<void> loadForMonth(int officeId, int year, int month) async {
    // Keep the previous month's values (counts, weekday totals, holiday/sick
    // counts) while the new data loads. Resetting the untracked fields to 0
    // here would make the percentage getters return null, causing the stat
    // cards' percentage badges to flicker off and back on every page change.
    state = state.copyWith(loading: true);

    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month + 1, 0);

    // The "year" stat follows the configured reporting year — the calendar
    // year by default, or the financial year (e.g. Oct–Sep) when selected on
    // the Explain page — so the dashboard and the Explain report agree.
    final fyStart = ref.read(settingsProvider).financialYearStart;
    final yearPeriod = ReportPeriod(
      kind: PeriodKind.year,
      anchor: DateTime(year, month, 15),
      financialYearStart: fyStart,
    );
    final yearStart = yearPeriod.start;
    final yearEnd = yearPeriod.end;

    final db = DatabaseService.instance;
    final records = await db.getAttendanceForMonth(year, month, officeId);
    final monthlyCount =
        await db.getAttendanceCount(officeId, from: monthStart, to: monthEnd);
    final yearlyCount =
        await db.getAttendanceCount(officeId, from: yearStart, to: yearEnd);
    final monthlyOfficeWeekdays = await db.getAttendanceCount(
      officeId,
      from: monthStart,
      to: monthEnd,
      weekdaysOnly: true,
    );
    final yearlyOfficeWeekdays = await db.getAttendanceCount(
      officeId,
      from: yearStart,
      to: yearEnd,
      weekdaysOnly: true,
    );
    final monthlyExcludedCount = await db.getSpecialDayCount(
      monthStart, monthEnd,
      types: excludedFromAttendanceDenominator,
    );
    final yearlyExcludedCount = await db.getSpecialDayCount(
      yearStart, yearEnd,
      types: excludedFromAttendanceDenominator,
    );

    state = AttendanceState(
      records: records,
      monthlyCount: monthlyCount,
      yearlyCount: yearlyCount,
      monthlyOfficeWeekdays: monthlyOfficeWeekdays,
      yearlyOfficeWeekdays: yearlyOfficeWeekdays,
      monthlyWeekdays: countWeekdays(monthStart, monthEnd),
      yearlyWeekdays: countWeekdays(yearStart, yearEnd),
      monthlyExcludedCount: monthlyExcludedCount,
      yearlyExcludedCount: yearlyExcludedCount,
    );
  }

  /// Records today's attendance. [focusedMonth] is the month the dashboard is
  /// currently showing — that's the month reloaded afterwards, so checking in
  /// while paged to another month doesn't swap the stats to the current month
  /// behind a stale header.
  Future<CheckInResult> manualCheckIn(
    int officeId, {
    required DateTime focusedMonth,
  }) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Prevent creating attendance on a holiday or sick-leave day.
    final specialDay = await DatabaseService.instance.getSpecialDayForDate(today);
    if (specialDay != null) return CheckInResult.specialDayConflict;

    final id = await DatabaseService.instance.insertAttendanceRecord(
      AttendanceRecord(
        date: today,
        officeLocationId: officeId,
        timestamp: DateTime.now(),
      ),
    );
    // Marking the day attended again revokes any earlier "deleted, don't
    // auto-record me today" dismissal.
    await DatabaseService.instance.undismissAutoCheckIn(today);
    await loadForMonth(officeId, focusedMonth.year, focusedMonth.month);
    if (id != null && id > 0) return CheckInResult.recorded;
    final existing = await DatabaseService.instance.getAttendanceForDate(today, officeId);
    if (existing?.reason == 'Auto check-in') return CheckInResult.alreadyRecordedByAuto;
    return CheckInResult.alreadyRecorded;
  }

  /// Inserts a new record or updates the reason on an existing one.
  Future<void> saveRecord(
    int officeId,
    String date, {
    String? reason,
  }) async {
    final existing = await DatabaseService.instance.getAttendanceForDate(
      date,
      officeId,
    );
    if (existing == null) {
      await DatabaseService.instance.insertAttendanceRecord(
        AttendanceRecord(
          date: date,
          officeLocationId: officeId,
          timestamp: DateTime.now(),
          reason: reason,
        ),
      );
    } else {
      await DatabaseService.instance.updateAttendanceRecord(
        AttendanceRecord(
          id: existing.id,
          date: existing.date,
          officeLocationId: existing.officeLocationId,
          timestamp: existing.timestamp,
          reason: reason,
        ),
      );
    }
    await DatabaseService.instance.undismissAutoCheckIn(date);
    final target = DateTime.parse(date);
    await loadForMonth(officeId, target.year, target.month);
  }

  Future<void> deleteRecord(String date, int officeId) async {
    await DatabaseService.instance.deleteAttendanceRecord(date, officeId);
    // The user explicitly removed this day, so stop auto check-in from
    // re-recording it — without this, deleting today's auto check-in while
    // still inside the office radius silently resurrects it on the next
    // geofence event or app resume.
    await DatabaseService.instance.dismissAutoCheckIn(date);
    // Reload so counts, weekdays, and percentages are fully recalculated.
    final target = DateTime.parse(date);
    await loadForMonth(officeId, target.year, target.month);
  }
}

final attendanceProvider = NotifierProvider<AttendanceNotifier, AttendanceState>(
  AttendanceNotifier.new,
);

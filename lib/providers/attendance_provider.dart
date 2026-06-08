import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/attendance_breakdown.dart';
import '../models/attendance_record.dart';
import '../models/special_day.dart';
import '../services/database_service.dart';

enum CheckInResult { recorded, alreadyRecorded, specialDayConflict }

class AttendanceState {
  final List<AttendanceRecord> records;
  final int monthlyCount;
  final int yearlyCount;
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
      monthlyWeekdays: monthlyWeekdays ?? this.monthlyWeekdays,
      yearlyWeekdays: yearlyWeekdays ?? this.yearlyWeekdays,
      monthlyExcludedCount: monthlyExcludedCount ?? this.monthlyExcludedCount,
      yearlyExcludedCount: yearlyExcludedCount ?? this.yearlyExcludedCount,
      loading: loading ?? this.loading,
    );
  }

  Set<DateTime> get attendanceDates =>
      records.map((r) => DateTime.parse(r.date)).toSet();

  double? get monthlyPercentage {
    final base = monthlyWeekdays - monthlyExcludedCount;
    if (base <= 0) return null;
    return (monthlyCount / base * 100).clamp(0.0, 100.0);
  }

  double? get yearlyPercentage {
    final base = yearlyWeekdays - yearlyExcludedCount;
    if (base <= 0) return null;
    return (yearlyCount / base * 100).clamp(0.0, 100.0);
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
    final yearStart = DateTime(year, 1, 1);
    final yearEnd = DateTime(year, 12, 31);

    final records = await DatabaseService.instance.getAttendanceForMonth(year, month, officeId);
    final monthlyCount = await DatabaseService.instance.getAttendanceCount(
      officeId,
      from: monthStart,
      to: monthEnd,
    );
    final yearlyCount = await DatabaseService.instance.getAttendanceCount(
      officeId,
      from: yearStart,
      to: yearEnd,
    );
    final monthlyExcludedCount = await DatabaseService.instance.getSpecialDayCount(
      monthStart, monthEnd,
      types: excludedFromAttendanceDenominator,
    );
    final yearlyExcludedCount = await DatabaseService.instance.getSpecialDayCount(
      yearStart, yearEnd,
      types: excludedFromAttendanceDenominator,
    );

    state = AttendanceState(
      records: records,
      monthlyCount: monthlyCount,
      yearlyCount: yearlyCount,
      monthlyWeekdays: countWeekdays(monthStart, monthEnd),
      yearlyWeekdays: countWeekdays(yearStart, yearEnd),
      monthlyExcludedCount: monthlyExcludedCount,
      yearlyExcludedCount: yearlyExcludedCount,
    );
  }

  Future<CheckInResult> manualCheckIn(int officeId) async {
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
    final now = DateTime.now();
    await loadForMonth(officeId, now.year, now.month);
    return id != null ? CheckInResult.recorded : CheckInResult.alreadyRecorded;
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
    final target = DateTime.parse(date);
    await loadForMonth(officeId, target.year, target.month);
  }

  Future<void> deleteRecord(String date, int officeId) async {
    await DatabaseService.instance.deleteAttendanceRecord(date, officeId);
    // Reload so counts, weekdays, and percentages are fully recalculated.
    final target = DateTime.parse(date);
    await loadForMonth(officeId, target.year, target.month);
  }
}

final attendanceProvider = NotifierProvider<AttendanceNotifier, AttendanceState>(
  AttendanceNotifier.new,
);

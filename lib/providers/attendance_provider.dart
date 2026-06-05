import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/attendance_record.dart';
import '../models/special_day.dart';
import '../services/database_service.dart';

enum CheckInResult { recorded, alreadyRecorded, specialDayConflict }

int _countWeekdays(DateTime start, DateTime end) {
  int count = 0;
  DateTime current = DateTime(start.year, start.month, start.day);
  final last = DateTime(end.year, end.month, end.day);
  while (!current.isAfter(last)) {
    final wd = current.weekday;
    if (wd != DateTime.saturday && wd != DateTime.sunday) count++;
    current = current.add(const Duration(days: 1));
  }
  return count;
}

class AttendanceState {
  final List<AttendanceRecord> records;
  final int monthlyCount;
  final int yearlyCount;
  final int monthlyWeekdays;
  final int yearlyWeekdays;
  final int monthlyHolidayCount;
  final int monthlySickLeaveCount;
  final int yearlyHolidayCount;
  final int yearlySickLeaveCount;
  final bool loading;

  const AttendanceState({
    this.records = const [],
    this.monthlyCount = 0,
    this.yearlyCount = 0,
    this.monthlyWeekdays = 0,
    this.yearlyWeekdays = 0,
    this.monthlyHolidayCount = 0,
    this.monthlySickLeaveCount = 0,
    this.yearlyHolidayCount = 0,
    this.yearlySickLeaveCount = 0,
    this.loading = false,
  });

  Set<DateTime> get attendanceDates =>
      records.map((r) => DateTime.parse(r.date)).toSet();

  double? get monthlyPercentage {
    final base = monthlyWeekdays - monthlyHolidayCount - monthlySickLeaveCount;
    if (base <= 0) return null;
    return (monthlyCount / base * 100).clamp(0.0, 100.0);
  }

  double? get yearlyPercentage {
    final base = yearlyWeekdays - yearlyHolidayCount - yearlySickLeaveCount;
    if (base <= 0) return null;
    return (yearlyCount / base * 100).clamp(0.0, 100.0);
  }
}

class AttendanceNotifier extends Notifier<AttendanceState> {
  @override
  AttendanceState build() => const AttendanceState();

  Future<void> loadForMonth(int officeId, int year, int month) async {
    state = AttendanceState(
      records: state.records,
      monthlyCount: state.monthlyCount,
      yearlyCount: state.yearlyCount,
      loading: true,
    );

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
    final monthlyHolidayCount = await DatabaseService.instance.getSpecialDayCount(
      monthStart, monthEnd,
      type: DayType.holiday,
    );
    final monthlySickLeaveCount = await DatabaseService.instance.getSpecialDayCount(
      monthStart, monthEnd,
      type: DayType.sickLeave,
    );
    final yearlyHolidayCount = await DatabaseService.instance.getSpecialDayCount(
      yearStart, yearEnd,
      type: DayType.holiday,
    );
    final yearlySickLeaveCount = await DatabaseService.instance.getSpecialDayCount(
      yearStart, yearEnd,
      type: DayType.sickLeave,
    );

    state = AttendanceState(
      records: records,
      monthlyCount: monthlyCount,
      yearlyCount: yearlyCount,
      monthlyWeekdays: _countWeekdays(monthStart, monthEnd),
      yearlyWeekdays: _countWeekdays(yearStart, yearEnd),
      monthlyHolidayCount: monthlyHolidayCount,
      monthlySickLeaveCount: monthlySickLeaveCount,
      yearlyHolidayCount: yearlyHolidayCount,
      yearlySickLeaveCount: yearlySickLeaveCount,
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

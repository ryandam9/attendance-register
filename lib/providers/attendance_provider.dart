import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/attendance_record.dart';
import '../services/database_service.dart';

class AttendanceState {
  final List<AttendanceRecord> records;
  final int monthlyCount;
  final int yearlyCount;
  final bool loading;

  const AttendanceState({
    this.records = const [],
    this.monthlyCount = 0,
    this.yearlyCount = 0,
    this.loading = false,
  });

  Set<DateTime> get attendanceDates =>
      records.map((r) => DateTime.parse(r.date)).toSet();
}

class AttendanceNotifier extends StateNotifier<AttendanceState> {
  AttendanceNotifier() : super(const AttendanceState());

  Future<void> loadForMonth(int officeId, int year, int month) async {
    state = AttendanceState(
      records: state.records,
      monthlyCount: state.monthlyCount,
      yearlyCount: state.yearlyCount,
      loading: true,
    );

    final records = await DatabaseService.instance.getAttendanceForMonth(year, month, officeId);
    final monthlyCount = await DatabaseService.instance.getAttendanceCount(
      officeId,
      from: DateTime(year, month, 1),
      to: DateTime(year, month + 1, 0),
    );
    final yearlyCount = await DatabaseService.instance.getAttendanceCount(
      officeId,
      from: DateTime(year, 1, 1),
      to: DateTime(year, 12, 31),
    );

    state = AttendanceState(
      records: records,
      monthlyCount: monthlyCount,
      yearlyCount: yearlyCount,
    );
  }

  Future<void> manualCheckIn(int officeId) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await DatabaseService.instance.insertAttendanceRecord(
      AttendanceRecord(
        date: today,
        officeLocationId: officeId,
        timestamp: DateTime.now(),
      ),
    );
    final now = DateTime.now();
    await loadForMonth(officeId, now.year, now.month);
  }

  Future<void> deleteRecord(String date, int officeId) async {
    await DatabaseService.instance.deleteAttendanceRecord(date, officeId);
    state = AttendanceState(
      records: state.records.where((r) => r.date != date).toList(),
      monthlyCount: state.monthlyCount,
      yearlyCount: state.yearlyCount,
    );
  }
}

final attendanceProvider = StateNotifierProvider<AttendanceNotifier, AttendanceState>(
  (_) => AttendanceNotifier(),
);

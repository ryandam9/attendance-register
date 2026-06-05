import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/attendance_record.dart';
import '../services/database_service.dart';

class AttendanceProvider extends ChangeNotifier {
  List<AttendanceRecord> _records = [];
  int _monthlyCount = 0;
  int _yearlyCount = 0;
  bool _loading = false;

  List<AttendanceRecord> get records => List.unmodifiable(_records);
  int get monthlyCount => _monthlyCount;
  int get yearlyCount => _yearlyCount;
  bool get loading => _loading;

  Set<DateTime> get attendanceDates =>
      _records.map((r) => DateTime.parse(r.date)).toSet();

  Future<void> loadForMonth(int officeId, int year, int month) async {
    _loading = true;
    notifyListeners();

    _records = await DatabaseService.instance.getAttendanceForMonth(
      year,
      month,
      officeId,
    );
    _monthlyCount = await DatabaseService.instance.getAttendanceCount(
      officeId,
      from: DateTime(year, month, 1),
      to: DateTime(year, month + 1, 0),
    );
    _yearlyCount = await DatabaseService.instance.getAttendanceCount(
      officeId,
      from: DateTime(year, 1, 1),
      to: DateTime(year, 12, 31),
    );

    _loading = false;
    notifyListeners();
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
    _records.removeWhere((r) => r.date == date);
    notifyListeners();
  }
}

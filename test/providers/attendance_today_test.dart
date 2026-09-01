import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:attendance_register/models/attendance_record.dart';
import 'package:attendance_register/models/office_location.dart';
import 'package:attendance_register/models/special_day.dart';
import 'package:attendance_register/providers/attendance_provider.dart';
import 'package:attendance_register/services/database_service.dart';

/// The "Today" card must describe today whatever month the calendar is showing.
/// Reading it out of the focused month's records made swiping back a month
/// report today as unrecorded — and offer to check in again.
void main() {
  final service = DatabaseService.instance;
  final today = DateTime.now();
  final todayKey = DateFormat('yyyy-MM-dd').format(today);
  // A month the calendar can be paged to that today never falls in.
  final otherMonth = DateTime(today.year, today.month - 2);

  late int officeId;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  setUp(() async {
    DatabaseService.overridePath = inMemoryDatabasePath;
    await service.reset();
    officeId = await service.insertOfficeLocation(
      const OfficeLocation(
        name: 'HQ',
        address: '1 Main St',
        latitude: 0,
        longitude: 0,
      ),
    );
  });

  tearDown(() async {
    await service.reset();
    DatabaseService.overridePath = null;
  });

  Future<AttendanceState> loadOtherMonth() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container
        .read(attendanceProvider.notifier)
        .loadForMonth(officeId, otherMonth.year, otherMonth.month);
    return container.read(attendanceProvider);
  }

  test('today reads as attended while another month is loaded', () async {
    await service.insertAttendanceRecord(
      AttendanceRecord(
        date: todayKey,
        officeLocationId: officeId,
        timestamp: today,
      ),
    );

    final state = await loadOtherMonth();

    // The loaded month genuinely does not contain today — otherwise the test
    // would pass for the wrong reason.
    expect(state.attendanceDateKeys, isNot(contains(todayKey)));
    expect(state.todayStatus, DayStatus.attended);
  });

  test('a special day on today survives paging too', () async {
    await service.upsertSpecialDay(
      SpecialDay(date: todayKey, type: DayType.sickLeave),
    );

    final state = await loadOtherMonth();
    expect(state.todayStatus, DayStatus.sickLeave);
  });

  test('an unrecorded today reads as null', () async {
    final state = await loadOtherMonth();
    expect(state.todayStatus, isNull);
  });
}

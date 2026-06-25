import 'package:attendance_register/models/attendance_record.dart';
import 'package:attendance_register/models/office_location.dart';
import 'package:attendance_register/models/special_day.dart';
import 'package:attendance_register/services/database_service.dart';
import 'package:attendance_register/services/export_service.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  final service = DatabaseService.instance;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  setUp(() async {
    DatabaseService.overridePath = inMemoryDatabasePath;
    await service.reset();
  });

  tearDown(() async {
    await service.reset();
    DatabaseService.overridePath = null;
  });

  Future<void> seed() async {
    final officeId = await service.insertOfficeLocation(
      const OfficeLocation(
        name: 'HQ',
        address: '1 Main St',
        latitude: 0,
        longitude: 0,
      ),
    );
    await service.insertAttendanceRecord(
      AttendanceRecord(
        date: '2026-06-10',
        officeLocationId: officeId,
        timestamp: DateTime(2026, 6, 10, 9),
        reason: 'Auto check-in',
      ),
    );
    await service.upsertSpecialDay(
      const SpecialDay(
        date: '2026-06-09',
        type: DayType.holiday,
        note: 'Holiday',
      ),
    );
  }

  test(
    'buildXlsx produces a decodable workbook with a header + all rows',
    () async {
      await seed();
      final result = await ExportService.buildXlsx();
      expect(result.rows, 2);
      expect(result.bytes, isNotEmpty);

      final decoded = Excel.decodeBytes(result.bytes);
      final sheet = decoded['History'];
      expect(sheet, isNotNull);
      // Header row + one row per recorded day.
      expect(sheet.maxRows, 3);

      String? cell(int row, int col) => sheet.rows[row][col]?.value?.toString();
      expect(cell(0, 0), 'date');
      expect(cell(0, 1), 'status');
      expect(cell(0, 2), 'office');
      expect(cell(0, 3), 'comment');

      // Newest first: the 06-10 attendance row precedes the 06-09 holiday.
      expect(cell(1, 0), '2026-06-10');
      expect(cell(1, 1), 'Attended');
      expect(cell(1, 2), 'HQ');
      expect(cell(2, 0), '2026-06-09');
    },
  );

  test(
    'buildXlsx on an empty database still yields a header-only sheet',
    () async {
      final result = await ExportService.buildXlsx();
      expect(result.rows, 0);
      final sheet = Excel.decodeBytes(result.bytes)['History'];
      expect(sheet.maxRows, 1); // just the header
    },
  );
}

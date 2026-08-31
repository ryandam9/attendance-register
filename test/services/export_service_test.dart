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
    final branchId = await service.insertOfficeLocation(
      const OfficeLocation(
        name: 'Branch',
        address: '2 High St',
        latitude: 0,
        longitude: 0,
      ),
    );
    await service.insertAttendanceRecord(
      AttendanceRecord(
        date: '2026-06-08',
        officeLocationId: branchId,
        timestamp: DateTime(2026, 6, 8, 8, 30),
        reason: 'Client workshop',
      ),
    );
    await service.upsertSpecialDay(
      const SpecialDay(
        date: '2026-06-09',
        type: DayType.holiday,
        note: 'Holiday',
        source: DaySource.auto,
      ),
    );
    await service.upsertSpecialDay(
      const SpecialDay(
        date: '2026-06-07',
        type: DayType.sickLeave,
        note: 'Rest day',
      ),
    );
  }

  test('buildXlsx produces a styled summary and complete history', () async {
    await seed();
    final result = await ExportService.buildXlsx(
      exportedAt: DateTime(2026, 8, 31, 17, 45),
    );
    expect(result.rows, 4);
    expect(result.bytes, isNotEmpty);

    final decoded = Excel.decodeBytes(result.bytes);
    expect(decoded.getDefaultSheet(), 'Summary');
    final summary = decoded['Summary'];
    final sheet = decoded['History'];
    expect(summary, isNotNull);
    expect(sheet, isNotNull);
    // Title, subtitle, spacer, header + one row per recorded day.
    expect(sheet.maxRows, 8);

    String? text(Sheet target, int row, int col) {
      final value = target
          .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
          .value;
      return value is TextCellValue ? value.value : null;
    }

    expect(text(summary, 0, 0), 'Attendance Register');
    expect(text(sheet, 0, 0), 'Complete Attendance History');
    expect(text(sheet, 3, 0), 'Date');
    expect(text(sheet, 3, 4), 'Entry source');
    expect(text(sheet, 3, 6), 'Notes');

    // Newest first, with every office and special day preserved.
    final firstDate = sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 4))
        .value;
    expect(firstDate, isA<DateCellValue>());
    expect(
      (firstDate! as DateCellValue).asDateTimeLocal(),
      DateTime(2026, 6, 10),
    );
    expect(text(sheet, 4, 2), 'Attended');
    expect(text(sheet, 4, 3), 'HQ');
    expect(text(sheet, 4, 4), 'Automatic check-in');
    expect(text(sheet, 5, 2), 'Public Holiday');
    expect(text(sheet, 5, 4), 'GitHub holiday import');
    expect(text(sheet, 6, 3), 'Branch');
    expect(text(sheet, 6, 4), 'Manual entry');
    expect(text(sheet, 7, 2), 'Sick Leave');

    // Visual hierarchy and practical widths survive workbook encoding.
    expect(
      summary.cell(CellIndex.indexByString('A1')).cellStyle?.isBold,
      isTrue,
    );
    expect(sheet.cell(CellIndex.indexByString('A4')).cellStyle?.isBold, isTrue);
    expect(sheet.getColumnWidth(0), 18);
    expect(sheet.getColumnWidth(6), 42);
  });

  test('buildCsv still includes every office and special day', () async {
    await seed();
    final result = await ExportService.buildCsv();
    expect(result.rows, 4);
    expect(result.csv, contains('2026-06-10,Attended,HQ,Auto check-in'));
    expect(result.csv, contains('2026-06-08,Attended,Branch,Client workshop'));
    expect(result.csv, contains('2026-06-09,Public Holiday,,Holiday'));
    expect(result.csv, contains('2026-06-07,Sick Leave,,Rest day'));
  });

  test(
    'buildXlsx on an empty database still yields a header-only sheet',
    () async {
      final result = await ExportService.buildXlsx();
      expect(result.rows, 0);
      final decoded = Excel.decodeBytes(result.bytes);
      expect(decoded.getDefaultSheet(), 'Summary');
      final sheet = decoded['History'];
      expect(sheet.maxRows, 4); // title, subtitle, spacer and header
    },
  );
}

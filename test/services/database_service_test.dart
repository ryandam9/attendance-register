import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:attendance_register/models/attendance_record.dart';
import 'package:attendance_register/models/office_location.dart';
import 'package:attendance_register/models/special_day.dart';
import 'package:attendance_register/services/database_service.dart';

// Helpers that exercise the database schema independently of the singleton,
// so tests are isolated and repeatable on any desktop environment.

Future<Database> _openTestDb() async {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;
  final db = await factory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 2,
      singleInstance: false,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE office_locations (
            id        INTEGER PRIMARY KEY AUTOINCREMENT,
            name      TEXT    NOT NULL,
            address   TEXT    NOT NULL,
            latitude  REAL    NOT NULL,
            longitude REAL    NOT NULL,
            radius    REAL    NOT NULL DEFAULT 200.0,
            country   TEXT,
            state     TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE attendance_records (
            id                 INTEGER PRIMARY KEY AUTOINCREMENT,
            date               TEXT    NOT NULL,
            office_location_id INTEGER NOT NULL,
            timestamp          TEXT    NOT NULL,
            reason             TEXT,
            FOREIGN KEY (office_location_id) REFERENCES office_locations(id)
          )
        ''');
        await db.execute(
          'CREATE UNIQUE INDEX idx_attendance_date '
          'ON attendance_records(date, office_location_id)',
        );
      },
    ),
  );
  return db;
}

// ── Office helper methods ─────────────────────────────────────────────────────

Future<int> _insertOffice(Database db, OfficeLocation loc) async {
  final map = loc.toMap()..remove('id');
  return db.insert('office_locations', map);
}

Future<List<OfficeLocation>> _getOffices(Database db) async {
  final rows = await db.query('office_locations');
  return rows.map(OfficeLocation.fromMap).toList();
}

// ── Attendance helper methods ─────────────────────────────────────────────────

Future<int?> _insertRecord(Database db, AttendanceRecord record) async {
  try {
    final map = record.toMap()..remove('id');
    return await db.insert(
      'attendance_records',
      map,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  } catch (_) {
    return null;
  }
}

Future<AttendanceRecord?> _getRecordForDate(
  Database db,
  String date,
  int officeId,
) async {
  final rows = await db.query(
    'attendance_records',
    where: 'date = ? AND office_location_id = ?',
    whereArgs: [date, officeId],
  );
  return rows.isEmpty ? null : AttendanceRecord.fromMap(rows.first);
}

Future<void> _updateRecord(Database db, AttendanceRecord record) async {
  await db.update(
    'attendance_records',
    record.toMap()..remove('id'),
    where: 'date = ? AND office_location_id = ?',
    whereArgs: [record.date, record.officeLocationId],
  );
}

Future<void> _deleteRecord(Database db, String date, int officeId) async {
  await db.delete(
    'attendance_records',
    where: 'date = ? AND office_location_id = ?',
    whereArgs: [date, officeId],
  );
}

Future<List<AttendanceRecord>> _getForMonth(
  Database db,
  int year,
  int month,
  int officeId,
) async {
  final start = '$year-${month.toString().padLeft(2, '0')}-01';
  final lastDay = DateTime(year, month + 1, 0).day;
  final end =
      '$year-${month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';
  final rows = await db.query(
    'attendance_records',
    where: 'date >= ? AND date <= ? AND office_location_id = ?',
    whereArgs: [start, end, officeId],
    orderBy: 'date ASC',
  );
  return rows.map(AttendanceRecord.fromMap).toList();
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  late Database db;

  setUp(() async {
    db = await _openTestDb();
  });

  tearDown(() async {
    await db.close();
  });

  // ── Office location CRUD ────────────────────────────────────────────────────

  group('Office location CRUD', () {
    const office = OfficeLocation(
      name: 'HQ',
      address: '1 Main St',
      latitude: 37.77,
      longitude: -122.42,
      radius: 200,
    );

    test('insert and retrieve office', () async {
      final id = await _insertOffice(db, office);
      final offices = await _getOffices(db);

      expect(offices, hasLength(1));
      expect(offices.first.id, id);
      expect(offices.first.name, 'HQ');
      expect(offices.first.radius, 200.0);
    });

    test('update office radius', () async {
      final id = await _insertOffice(db, office);
      final updated = office.copyWith(id: id, radius: 350.0);

      await db.update(
        'office_locations',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [id],
      );

      final offices = await _getOffices(db);
      expect(offices.first.radius, 350.0);
    });

    test('delete office', () async {
      final id = await _insertOffice(db, office);
      await db.delete('office_locations', where: 'id = ?', whereArgs: [id]);

      final offices = await _getOffices(db);
      expect(offices, isEmpty);
    });
  });

  // ── Attendance record CRUD ──────────────────────────────────────────────────

  group('Attendance record CRUD', () {
    late int officeId;
    final ts = DateTime(2025, 6, 15, 9, 0);

    setUp(() async {
      officeId = await _insertOffice(
        db,
        const OfficeLocation(
          name: 'Test Office',
          address: 'Test Address',
          latitude: 0,
          longitude: 0,
        ),
      );
    });

    test('insert and retrieve record', () async {
      final record = AttendanceRecord(
        date: '2025-06-15',
        officeLocationId: officeId,
        timestamp: ts,
        reason: 'Manual entry',
      );

      await _insertRecord(db, record);
      final fetched = await _getRecordForDate(db, '2025-06-15', officeId);

      expect(fetched, isNotNull);
      expect(fetched!.date, '2025-06-15');
      expect(fetched.reason, 'Manual entry');
    });

    test('insert record without reason stores null', () async {
      final record = AttendanceRecord(
        date: '2025-06-16',
        officeLocationId: officeId,
        timestamp: ts,
      );

      await _insertRecord(db, record);
      final fetched = await _getRecordForDate(db, '2025-06-16', officeId);

      expect(fetched!.reason, isNull);
    });

    test('duplicate insert is ignored', () async {
      final record = AttendanceRecord(
        date: '2025-06-15',
        officeLocationId: officeId,
        timestamp: ts,
        reason: 'First',
      );

      final id1 = await _insertRecord(db, record);
      final id2 = await _insertRecord(db, record);

      expect(id1, isNotNull);
      // ignore returns 0 on conflict
      expect(id2, 0);

      final rows = await db.query('attendance_records');
      expect(rows, hasLength(1));
    });

    test('update reason on existing record', () async {
      final record = AttendanceRecord(
        date: '2025-06-15',
        officeLocationId: officeId,
        timestamp: ts,
        reason: 'Original reason',
      );
      await _insertRecord(db, record);

      final existing = await _getRecordForDate(db, '2025-06-15', officeId);
      await _updateRecord(
        db,
        AttendanceRecord(
          id: existing!.id,
          date: existing.date,
          officeLocationId: existing.officeLocationId,
          timestamp: existing.timestamp,
          reason: 'Updated reason',
        ),
      );

      final updated = await _getRecordForDate(db, '2025-06-15', officeId);
      expect(updated!.reason, 'Updated reason');
    });

    test('delete record', () async {
      await _insertRecord(
        db,
        AttendanceRecord(
          date: '2025-06-15',
          officeLocationId: officeId,
          timestamp: ts,
        ),
      );

      await _deleteRecord(db, '2025-06-15', officeId);
      final fetched = await _getRecordForDate(db, '2025-06-15', officeId);

      expect(fetched, isNull);
    });

    test('getForMonth returns only records in range', () async {
      final dates = ['2025-06-01', '2025-06-15', '2025-06-30', '2025-07-01'];
      for (final d in dates) {
        await _insertRecord(
          db,
          AttendanceRecord(
            date: d,
            officeLocationId: officeId,
            timestamp: ts,
          ),
        );
      }

      final june = await _getForMonth(db, 2025, 6, officeId);
      expect(june, hasLength(3));
      expect(june.map((r) => r.date), containsAll(['2025-06-01', '2025-06-15', '2025-06-30']));

      final july = await _getForMonth(db, 2025, 7, officeId);
      expect(july, hasLength(1));
      expect(july.first.date, '2025-07-01');
    });

    test('records for different offices are independent', () async {
      final officeId2 = await _insertOffice(
        db,
        const OfficeLocation(
          name: 'Branch',
          address: 'Branch Rd',
          latitude: 1,
          longitude: 1,
        ),
      );

      await _insertRecord(
        db,
        AttendanceRecord(
          date: '2025-06-15',
          officeLocationId: officeId,
          timestamp: ts,
        ),
      );
      await _insertRecord(
        db,
        AttendanceRecord(
          date: '2025-06-15',
          officeLocationId: officeId2,
          timestamp: ts,
          reason: 'Branch visit',
        ),
      );

      final rec1 = await _getRecordForDate(db, '2025-06-15', officeId);
      final rec2 = await _getRecordForDate(db, '2025-06-15', officeId2);

      expect(rec1!.reason, isNull);
      expect(rec2!.reason, 'Branch visit');
    });
  });

  // ── DatabaseService (full schema, in-memory) ────────────────────────────────
  //
  // These run against the real service — schema creation, PRAGMAs, transactions
  // and query helpers included — using an in-memory database via overridePath.

  group('DatabaseService', () {
    final service = DatabaseService.instance;
    final ts = DateTime(2026, 6, 8, 9, 0);

    setUp(() async {
      // The service opens via sqflite's global factory — point it at ffi.
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      DatabaseService.overridePath = inMemoryDatabasePath;
      await service.reset();
    });

    tearDown(() async {
      await service.reset();
      DatabaseService.overridePath = null;
    });

    Future<int> insertOffice({String name = 'HQ'}) =>
        service.insertOfficeLocation(OfficeLocation(
          name: name,
          address: '1 Main St',
          latitude: 0,
          longitude: 0,
        ));

    Future<void> insertRecordOn(String date, int officeId) =>
        service.insertAttendanceRecord(AttendanceRecord(
          date: date,
          officeLocationId: officeId,
          timestamp: ts,
        ));

    group('getAttendanceCount', () {
      test('weekdaysOnly excludes weekend check-ins', () async {
        final officeId = await insertOffice();
        // June 2026: the 5th is a Friday, 6th Saturday, 7th Sunday, 8th Monday.
        for (final d in ['2026-06-05', '2026-06-06', '2026-06-07', '2026-06-08']) {
          await insertRecordOn(d, officeId);
        }

        final all = await service.getAttendanceCount(
          officeId,
          from: DateTime(2026, 6, 1),
          to: DateTime(2026, 6, 30),
        );
        final weekdays = await service.getAttendanceCount(
          officeId,
          from: DateTime(2026, 6, 1),
          to: DateTime(2026, 6, 30),
          weekdaysOnly: true,
        );

        expect(all, 4);
        expect(weekdays, 2); // Friday + Monday
      });
    });

    group('deleteOfficeLocation', () {
      test('removes the office and its records, leaving other offices intact',
          () async {
        final officeId1 = await insertOffice(name: 'HQ');
        final officeId2 = await insertOffice(name: 'Branch');
        await insertRecordOn('2026-06-08', officeId1);
        await insertRecordOn('2026-06-08', officeId2);

        await service.deleteOfficeLocation(officeId1);

        expect(await service.getOfficeLocation(officeId1), isNull);
        expect(await service.getAllAttendanceRecords(officeId1), isEmpty);
        expect(await service.getAllAttendanceRecords(officeId2), hasLength(1));
      });
    });

    group('bulk date getters (holiday importer)', () {
      test('getAllAttendanceDates de-duplicates across offices', () async {
        final officeId1 = await insertOffice(name: 'HQ');
        final officeId2 = await insertOffice(name: 'Branch');
        await insertRecordOn('2026-06-08', officeId1);
        await insertRecordOn('2026-06-08', officeId2);
        await insertRecordOn('2026-06-09', officeId1);

        expect(
          await service.getAllAttendanceDates(),
          {'2026-06-08', '2026-06-09'},
        );
      });

      test('getAllSpecialDayDates returns every special-day date', () async {
        await service.upsertSpecialDay(
          const SpecialDay(date: '2026-06-01', type: DayType.holiday),
        );
        await service.upsertSpecialDay(
          const SpecialDay(date: '2026-06-02', type: DayType.sickLeave),
        );

        expect(
          await service.getAllSpecialDayDates(),
          {'2026-06-01', '2026-06-02'},
        );
      });
    });
  });
}

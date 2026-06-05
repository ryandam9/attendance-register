import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:attendance_register/models/attendance_record.dart';
import 'package:attendance_register/models/office_location.dart';
import 'package:attendance_register/models/special_day.dart';

// Full v3 in-memory database matching the production schema.
Future<Database> _openTestDb() async {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;
  return factory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 3,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE office_locations (
            id        INTEGER PRIMARY KEY AUTOINCREMENT,
            name      TEXT    NOT NULL,
            address   TEXT    NOT NULL,
            latitude  REAL    NOT NULL,
            longitude REAL    NOT NULL,
            radius    REAL    NOT NULL DEFAULT 200.0
          )
        ''');
        await db.execute('''
          CREATE TABLE attendance_records (
            id                 INTEGER PRIMARY KEY AUTOINCREMENT,
            date               TEXT    NOT NULL,
            office_location_id INTEGER NOT NULL,
            timestamp          TEXT    NOT NULL,
            reason             TEXT
          )
        ''');
        await db.execute(
          'CREATE UNIQUE INDEX idx_attendance_date '
          'ON attendance_records(date, office_location_id)',
        );
        await db.execute('''
          CREATE TABLE special_days (
            id    INTEGER PRIMARY KEY AUTOINCREMENT,
            date  TEXT    NOT NULL UNIQUE,
            type  TEXT    NOT NULL,
            note  TEXT
          )
        ''');
      },
    ),
  );
}

// ── DB helpers ────────────────────────────────────────────────────────────────

Future<int> _insertOffice(Database db, OfficeLocation loc) async {
  final map = loc.toMap()..remove('id');
  return db.insert('office_locations', map);
}

Future<OfficeLocation?> _getOfficeById(Database db, int id) async {
  final rows = await db.query('office_locations', where: 'id = ?', whereArgs: [id]);
  return rows.isEmpty ? null : OfficeLocation.fromMap(rows.first);
}

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

Future<bool> _hasRecord(Database db, String date, int officeId) async {
  final rows = await db.query(
    'attendance_records',
    where: 'date = ? AND office_location_id = ?',
    whereArgs: [date, officeId],
  );
  return rows.isNotEmpty;
}

Future<int> _countRecords(
  Database db,
  int officeId, {
  DateTime? from,
  DateTime? to,
}) async {
  String fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String where = 'office_location_id = ?';
  final args = <dynamic>[officeId];
  if (from != null) {
    where += ' AND date >= ?';
    args.add(fmt(from));
  }
  if (to != null) {
    where += ' AND date <= ?';
    args.add(fmt(to));
  }

  final result = await db.rawQuery(
    'SELECT COUNT(*) AS cnt FROM attendance_records WHERE $where',
    args,
  );
  return (result.first['cnt'] as int?) ?? 0;
}

// Application-level cascade delete (mirrors DatabaseService.deleteOfficeLocation).
Future<void> _deleteOfficeCascade(Database db, int id) async {
  await db.delete('office_locations', where: 'id = ?', whereArgs: [id]);
  await db.delete('attendance_records', where: 'office_location_id = ?', whereArgs: [id]);
}

Future<void> _deleteAllRecords(Database db) async {
  await db.delete('attendance_records');
  await db.delete('special_days');
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late Database db;
  final ts = DateTime(2025, 6, 15, 9, 0);

  setUp(() async {
    db = await _openTestDb();
  });

  tearDown(() async {
    await db.close();
  });

  // ── hasAttendanceForDate ──────────────────────────────────────────────────

  group('hasAttendanceForDate', () {
    late int officeId;

    setUp(() async {
      officeId = await _insertOffice(
        db,
        const OfficeLocation(
          name: 'Test Office',
          address: 'Test Rd',
          latitude: 0,
          longitude: 0,
        ),
      );
    });

    test('returns true after inserting a record', () async {
      await _insertRecord(
        db,
        AttendanceRecord(
          date: '2025-06-15',
          officeLocationId: officeId,
          timestamp: ts,
        ),
      );

      expect(await _hasRecord(db, '2025-06-15', officeId), isTrue);
    });

    test('returns false when no record exists', () async {
      expect(await _hasRecord(db, '2025-06-20', officeId), isFalse);
    });

    test('returns false after the record is deleted', () async {
      await _insertRecord(
        db,
        AttendanceRecord(
          date: '2025-06-15',
          officeLocationId: officeId,
          timestamp: ts,
        ),
      );
      await db.delete(
        'attendance_records',
        where: 'date = ? AND office_location_id = ?',
        whereArgs: ['2025-06-15', officeId],
      );

      expect(await _hasRecord(db, '2025-06-15', officeId), isFalse);
    });

    test('is office-specific — does not match a different office', () async {
      final otherId = await _insertOffice(
        db,
        const OfficeLocation(name: 'Other', address: 'Other Rd', latitude: 1, longitude: 1),
      );
      await _insertRecord(
        db,
        AttendanceRecord(
          date: '2025-06-15',
          officeLocationId: otherId,
          timestamp: ts,
        ),
      );

      expect(await _hasRecord(db, '2025-06-15', officeId), isFalse);
    });
  });

  // ── getAttendanceCount ────────────────────────────────────────────────────

  group('getAttendanceCount', () {
    late int officeId;

    setUp(() async {
      officeId = await _insertOffice(
        db,
        const OfficeLocation(
          name: 'Count Office',
          address: 'Count Rd',
          latitude: 0,
          longitude: 0,
        ),
      );

      for (final date in [
        '2025-06-02',
        '2025-06-09',
        '2025-06-16',
        '2025-07-07',
      ]) {
        await _insertRecord(
          db,
          AttendanceRecord(date: date, officeLocationId: officeId, timestamp: ts),
        );
      }
    });

    test('returns total count without a date range', () async {
      final count = await _countRecords(db, officeId);
      expect(count, 4);
    });

    test('counts records within the given date range', () async {
      final count = await _countRecords(
        db,
        officeId,
        from: DateTime(2025, 6, 1),
        to: DateTime(2025, 6, 30),
      );
      expect(count, 3);
    });

    test('excludes records outside the date range', () async {
      final count = await _countRecords(
        db,
        officeId,
        from: DateTime(2025, 7, 1),
        to: DateTime(2025, 7, 31),
      );
      expect(count, 1);
    });

    test('returns 0 when no records match the range', () async {
      final count = await _countRecords(
        db,
        officeId,
        from: DateTime(2025, 8, 1),
        to: DateTime(2025, 8, 31),
      );
      expect(count, 0);
    });

    test('boundary dates are inclusive', () async {
      final count = await _countRecords(
        db,
        officeId,
        from: DateTime(2025, 6, 2),
        to: DateTime(2025, 6, 16),
      );
      expect(count, 3); // 06-02, 06-09, 06-16
    });

    test('count is isolated to the specified office', () async {
      final otherId = await _insertOffice(
        db,
        const OfficeLocation(name: 'Other', address: 'Other Rd', latitude: 1, longitude: 1),
      );
      await _insertRecord(
        db,
        AttendanceRecord(date: '2025-06-02', officeLocationId: otherId, timestamp: ts),
      );

      final count = await _countRecords(db, otherId);
      expect(count, 1);
    });
  });

  // ── getOfficeLocation (by id) ─────────────────────────────────────────────

  group('getOfficeLocation by id', () {
    test('returns the correct office for a known id', () async {
      final id = await _insertOffice(
        db,
        const OfficeLocation(
          name: 'Lookup HQ',
          address: '42 Elm St',
          latitude: 51.5,
          longitude: -0.1,
          radius: 150.0,
        ),
      );

      final office = await _getOfficeById(db, id);

      expect(office, isNotNull);
      expect(office!.name, 'Lookup HQ');
      expect(office.radius, 150.0);
    });

    test('returns null for a non-existent id', () async {
      final office = await _getOfficeById(db, 9999);
      expect(office, isNull);
    });
  });

  // ── Cascade delete ────────────────────────────────────────────────────────

  group('Cascade delete (application-level)', () {
    test('deleting an office also deletes its attendance records', () async {
      final id = await _insertOffice(
        db,
        const OfficeLocation(name: 'HQ', address: 'HQ Rd', latitude: 0, longitude: 0),
      );

      for (final date in ['2025-06-01', '2025-06-02', '2025-06-03']) {
        await _insertRecord(
          db,
          AttendanceRecord(date: date, officeLocationId: id, timestamp: ts),
        );
      }

      await _deleteOfficeCascade(db, id);

      final remaining = await db.query(
        'attendance_records',
        where: 'office_location_id = ?',
        whereArgs: [id],
      );
      expect(remaining, isEmpty);
    });

    test('only records belonging to the deleted office are removed', () async {
      final id1 = await _insertOffice(
        db,
        const OfficeLocation(name: 'Office A', address: 'A Rd', latitude: 0, longitude: 0),
      );
      final id2 = await _insertOffice(
        db,
        const OfficeLocation(name: 'Office B', address: 'B Rd', latitude: 1, longitude: 1),
      );

      await _insertRecord(
        db,
        AttendanceRecord(date: '2025-06-01', officeLocationId: id1, timestamp: ts),
      );
      await _insertRecord(
        db,
        AttendanceRecord(date: '2025-06-01', officeLocationId: id2, timestamp: ts),
      );

      await _deleteOfficeCascade(db, id1);

      final allRecords = await db.query('attendance_records');
      expect(allRecords, hasLength(1));
      expect(allRecords.first['office_location_id'], id2);
    });

    test('the office row itself is removed', () async {
      final id = await _insertOffice(
        db,
        const OfficeLocation(name: 'Gone', address: 'Gone Rd', latitude: 0, longitude: 0),
      );

      await _deleteOfficeCascade(db, id);

      final office = await _getOfficeById(db, id);
      expect(office, isNull);
    });
  });

  // ── deleteAllRecords ──────────────────────────────────────────────────────

  group('deleteAllRecords', () {
    test('clears all attendance records and special days', () async {
      final officeId = await _insertOffice(
        db,
        const OfficeLocation(name: 'HQ', address: 'HQ Rd', latitude: 0, longitude: 0),
      );

      await _insertRecord(
        db,
        AttendanceRecord(date: '2025-06-01', officeLocationId: officeId, timestamp: ts),
      );
      await db.insert('special_days', {
        'date': '2025-01-01',
        'type': 'holiday',
        'note': null,
      });

      await _deleteAllRecords(db);

      final records = await db.query('attendance_records');
      final specialDays = await db.query('special_days');

      expect(records, isEmpty);
      expect(specialDays, isEmpty);
    });

    test('does not delete office location rows', () async {
      final officeId = await _insertOffice(
        db,
        const OfficeLocation(name: 'HQ', address: 'HQ Rd', latitude: 0, longitude: 0),
      );

      await _deleteAllRecords(db);

      final office = await _getOfficeById(db, officeId);
      expect(office, isNotNull);
    });

    test('is idempotent on empty tables', () async {
      await _deleteAllRecords(db);
      await _deleteAllRecords(db);

      final records = await db.query('attendance_records');
      final specialDays = await db.query('special_days');

      expect(records, isEmpty);
      expect(specialDays, isEmpty);
    });
  });
}

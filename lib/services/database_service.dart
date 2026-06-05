import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/attendance_record.dart';
import '../models/office_location.dart';
import '../models/special_day.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'attendance.db'),
      version: 3,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE office_locations (
            id      INTEGER PRIMARY KEY AUTOINCREMENT,
            name    TEXT    NOT NULL,
            address TEXT    NOT NULL,
            latitude  REAL  NOT NULL,
            longitude REAL  NOT NULL,
            radius    REAL  NOT NULL DEFAULT 200.0
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

        // One record per day per office.
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
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE attendance_records ADD COLUMN reason TEXT',
          );
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS special_days (
              id    INTEGER PRIMARY KEY AUTOINCREMENT,
              date  TEXT    NOT NULL UNIQUE,
              type  TEXT    NOT NULL,
              note  TEXT
            )
          ''');
        }
      },
    );
  }

  // ── Office Locations ─────────────────────────────────────────────────────

  Future<int> insertOfficeLocation(OfficeLocation loc) async {
    final db = await database;
    final map = loc.toMap()..remove('id');
    return db.insert('office_locations', map);
  }

  Future<List<OfficeLocation>> getOfficeLocations() async {
    final db = await database;
    final rows = await db.query('office_locations');
    return rows.map(OfficeLocation.fromMap).toList();
  }

  Future<OfficeLocation?> getOfficeLocation(int id) async {
    final db = await database;
    final rows = await db.query(
      'office_locations',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : OfficeLocation.fromMap(rows.first);
  }

  Future<void> updateOfficeLocation(OfficeLocation loc) async {
    final db = await database;
    await db.update(
      'office_locations',
      loc.toMap(),
      where: 'id = ?',
      whereArgs: [loc.id],
    );
  }

  Future<void> deleteOfficeLocation(int id) async {
    final db = await database;
    await db.delete('office_locations', where: 'id = ?', whereArgs: [id]);
    await db.delete(
      'attendance_records',
      where: 'office_location_id = ?',
      whereArgs: [id],
    );
  }

  // ── Attendance Records ────────────────────────────────────────────────────

  Future<bool> hasAttendanceForDate(String date, int officeId) async {
    final db = await database;
    final rows = await db.query(
      'attendance_records',
      where: 'date = ? AND office_location_id = ?',
      whereArgs: [date, officeId],
    );
    return rows.isNotEmpty;
  }

  Future<AttendanceRecord?> getAttendanceForDate(
    String date,
    int officeId,
  ) async {
    final db = await database;
    final rows = await db.query(
      'attendance_records',
      where: 'date = ? AND office_location_id = ?',
      whereArgs: [date, officeId],
    );
    return rows.isEmpty ? null : AttendanceRecord.fromMap(rows.first);
  }

  Future<int?> insertAttendanceRecord(AttendanceRecord record) async {
    final db = await database;
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

  Future<void> updateAttendanceRecord(AttendanceRecord record) async {
    final db = await database;
    await db.update(
      'attendance_records',
      record.toMap()..remove('id'),
      where: 'date = ? AND office_location_id = ?',
      whereArgs: [record.date, record.officeLocationId],
    );
  }

  Future<List<AttendanceRecord>> getAttendanceForMonth(
    int year,
    int month,
    int officeId,
  ) async {
    final db = await database;
    final start = '$year-${month.toString().padLeft(2, '0')}-01';
    final lastDay = DateTime(year, month + 1, 0).day;
    final end = '$year-${month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';

    final rows = await db.query(
      'attendance_records',
      where: 'date >= ? AND date <= ? AND office_location_id = ?',
      whereArgs: [start, end, officeId],
      orderBy: 'date ASC',
    );
    return rows.map(AttendanceRecord.fromMap).toList();
  }

  Future<int> getAttendanceCount(
    int officeId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await database;
    String where = 'office_location_id = ?';
    final args = <dynamic>[officeId];

    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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

  Future<void> deleteAttendanceRecord(String date, int officeId) async {
    final db = await database;
    await db.delete(
      'attendance_records',
      where: 'date = ? AND office_location_id = ?',
      whereArgs: [date, officeId],
    );
  }

  // ── Special Days ──────────────────────────────────────────────────────────

  Future<void> upsertSpecialDay(SpecialDay day) async {
    final db = await database;
    final map = day.toMap()..remove('id');
    await db.insert(
      'special_days',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<SpecialDay?> getSpecialDayForDate(String date) async {
    final db = await database;
    final rows = await db.query(
      'special_days',
      where: 'date = ?',
      whereArgs: [date],
    );
    return rows.isEmpty ? null : SpecialDay.fromMap(rows.first);
  }

  Future<List<SpecialDay>> getSpecialDaysForMonth(int year, int month) async {
    final db = await database;
    final start = '$year-${month.toString().padLeft(2, '0')}-01';
    final lastDay = DateTime(year, month + 1, 0).day;
    final end =
        '$year-${month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';
    final rows = await db.query(
      'special_days',
      where: 'date >= ? AND date <= ?',
      whereArgs: [start, end],
      orderBy: 'date ASC',
    );
    return rows.map(SpecialDay.fromMap).toList();
  }

  Future<int> getSpecialDayCount(
    DateTime from,
    DateTime to, {
    DayType? type,
  }) async {
    final db = await database;
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    String where = 'date >= ? AND date <= ?';
    final args = <dynamic>[fmt(from), fmt(to)];

    if (type != null) {
      where += ' AND type = ?';
      args.add(type.name);
    }

    final result = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM special_days WHERE $where',
      args,
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  Future<void> deleteSpecialDay(String date) async {
    final db = await database;
    await db.delete('special_days', where: 'date = ?', whereArgs: [date]);
  }
}

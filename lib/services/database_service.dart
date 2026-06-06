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
      version: 4,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE office_locations (
            id      INTEGER PRIMARY KEY AUTOINCREMENT,
            name    TEXT    NOT NULL,
            address TEXT    NOT NULL,
            latitude  REAL  NOT NULL,
            longitude REAL  NOT NULL,
            radius    REAL  NOT NULL DEFAULT 200.0,
            country TEXT,
            state   TEXT
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
            id     INTEGER PRIMARY KEY AUTOINCREMENT,
            date   TEXT    NOT NULL UNIQUE,
            type   TEXT    NOT NULL,
            note   TEXT,
            source TEXT    NOT NULL DEFAULT 'manual'
          )
        ''');

        // Dates the user explicitly removed an auto-imported holiday from. The
        // importer skips these so a deleted public holiday is not resurrected on
        // the next sync.
        await db.execute('''
          CREATE TABLE dismissed_holidays (
            date TEXT PRIMARY KEY
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
        if (oldVersion < 4) {
          await db.execute(
            'ALTER TABLE office_locations ADD COLUMN country TEXT',
          );
          await db.execute(
            'ALTER TABLE office_locations ADD COLUMN state TEXT',
          );
          await db.execute(
            "ALTER TABLE special_days "
            "ADD COLUMN source TEXT NOT NULL DEFAULT 'manual'",
          );
          await db.execute('''
            CREATE TABLE IF NOT EXISTS dismissed_holidays (
              date TEXT PRIMARY KEY
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

  /// True when attendance was recorded at *any* office on [date]. Used by the
  /// holiday importer so it never marks a day you actually worked as a holiday.
  Future<bool> hasAnyAttendanceForDate(String date) async {
    final db = await database;
    final rows = await db.query(
      'attendance_records',
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
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

  /// Counts special days in [from]..[to]. Only weekdays (Mon–Fri) are counted:
  /// the attendance percentage denominator is built from weekdays, so a holiday
  /// or sick day that falls on a weekend must not be subtracted from it (doing
  /// so would shrink the denominator below the real number of working days).
  /// SQLite's strftime('%w') returns 0 for Sunday and 6 for Saturday.
  Future<int> getSpecialDayCount(
    DateTime from,
    DateTime to, {
    DayType? type,
  }) async {
    final db = await database;
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    String where =
        "date >= ? AND date <= ? AND strftime('%w', date) NOT IN ('0', '6')";
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

  /// Every attendance record for an office, newest first — used by the history
  /// list view.
  Future<List<AttendanceRecord>> getAllAttendanceRecords(int officeId) async {
    final db = await database;
    final rows = await db.query(
      'attendance_records',
      where: 'office_location_id = ?',
      whereArgs: [officeId],
      orderBy: 'date DESC',
    );
    return rows.map(AttendanceRecord.fromMap).toList();
  }

  /// Every special day (holiday / sick leave / not attended), newest first.
  Future<List<SpecialDay>> getAllSpecialDays() async {
    final db = await database;
    final rows = await db.query('special_days', orderBy: 'date DESC');
    return rows.map(SpecialDay.fromMap).toList();
  }

  Future<void> deleteSpecialDay(String date) async {
    final db = await database;
    await db.delete('special_days', where: 'date = ?', whereArgs: [date]);
  }

  // ── Dismissed (auto) holidays ─────────────────────────────────────────────

  /// Remember that the user removed an auto-imported holiday on [date] so the
  /// importer does not re-add it on the next sync.
  Future<void> dismissHoliday(String date) async {
    final db = await database;
    await db.insert(
      'dismissed_holidays',
      {'date': date},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<Set<String>> getDismissedHolidayDates() async {
    final db = await database;
    final rows = await db.query('dismissed_holidays', columns: ['date']);
    return rows.map((r) => r['date'] as String).toSet();
  }

  Future<void> deleteAllRecords() async {
    final db = await database;
    await db.delete('attendance_records');
    await db.delete('special_days');
    await db.delete('dismissed_holidays');
  }
}

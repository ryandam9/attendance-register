import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/attendance_record.dart';
import '../models/office_location.dart';
import '../models/special_day.dart';

/// Formats [d] as the `YYYY-MM-DD` key used by every date column.
String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  /// When set (in tests), the database is opened at this path (e.g.
  /// `inMemoryDatabasePath`) instead of the on-device file.
  @visibleForTesting
  static String? overridePath;

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  /// Closes and clears the cached connection so the next access reopens it —
  /// gives each test a fresh in-memory database.
  @visibleForTesting
  Future<void> reset() async {
    await _db?.close();
    _db = null;
  }

  Future<Database> _open() async {
    final path =
        overridePath ?? join(await getDatabasesPath(), 'attendance.db');
    return openDatabase(
      path,
      version: 7,
      // sqflite does not enforce FOREIGN KEY constraints unless explicitly
      // enabled per connection.
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
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

        // Simple key/value store for app preferences (e.g. the financial-year
        // start used by the Explain report).
        await db.execute('''
          CREATE TABLE app_settings (
            key   TEXT PRIMARY KEY,
            value TEXT NOT NULL
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
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS app_settings (
              key   TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 6) {
          // 'Not attended' was renamed to 'Misc leave' and is now excluded from
          // the attendance-percentage denominator. Convert existing rows so they
          // parse back to the new DayType.miscLeave instead of crashing.
          await db.execute(
            "UPDATE special_days SET type = 'miscLeave' WHERE type = 'notAttended'",
          );
        }
        if (oldVersion < 7) {
          // Foreign keys were not enforced before v7, and office deletion was
          // not transactional, so a crash mid-delete could leave attendance
          // rows pointing at a removed office. Clean those up before the
          // PRAGMA starts rejecting writes that touch them.
          await db.execute(
            'DELETE FROM attendance_records WHERE office_location_id '
            'NOT IN (SELECT id FROM office_locations)',
          );
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
    // One transaction so a crash can't leave attendance rows orphaned. Records
    // go first: with foreign keys enforced, deleting the office while rows
    // still reference it would be rejected.
    await db.transaction((txn) async {
      await txn.delete(
        'attendance_records',
        where: 'office_location_id = ?',
        whereArgs: [id],
      );
      await txn.delete('office_locations', where: 'id = ?', whereArgs: [id]);
    });
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

  /// Every date (at any office) with an attendance record. Used by the holiday
  /// importer so it never marks a day you actually worked as a holiday.
  Future<Set<String>> getAllAttendanceDates() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT date FROM attendance_records',
    );
    return rows.map((r) => r['date'] as String).toSet();
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

  /// Counts attendance records for [officeId], optionally restricted to
  /// [from]..[to]. With [weekdaysOnly] set, weekend check-ins are excluded —
  /// used by the attendance percentage, whose denominator is built from
  /// weekdays, so a Saturday at the office must not inflate it.
  /// SQLite's strftime('%w') returns 0 for Sunday and 6 for Saturday.
  Future<int> getAttendanceCount(
    int officeId, {
    DateTime? from,
    DateTime? to,
    bool weekdaysOnly = false,
  }) async {
    final db = await database;
    String where = 'office_location_id = ?';
    final args = <dynamic>[officeId];

    if (from != null) {
      where += ' AND date >= ?';
      args.add(_fmtDate(from));
    }
    if (to != null) {
      where += ' AND date <= ?';
      args.add(_fmtDate(to));
    }
    if (weekdaysOnly) {
      where += " AND strftime('%w', date) NOT IN ('0', '6')";
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
  /// or leave day that falls on a weekend must not be subtracted from it (doing
  /// so would shrink the denominator below the real number of working days).
  /// SQLite's strftime('%w') returns 0 for Sunday and 6 for Saturday.
  ///
  /// When [types] is given, only those day types are counted (e.g. the set of
  /// leave types excluded from the attendance denominator); when null, every
  /// special day in range is counted.
  Future<int> getSpecialDayCount(
    DateTime from,
    DateTime to, {
    Iterable<DayType>? types,
  }) async {
    final db = await database;

    String where =
        "date >= ? AND date <= ? AND strftime('%w', date) NOT IN ('0', '6')";
    final args = <dynamic>[_fmtDate(from), _fmtDate(to)];

    final typeList = types?.toList();
    if (typeList != null && typeList.isNotEmpty) {
      final placeholders = List.filled(typeList.length, '?').join(', ');
      where += ' AND type IN ($placeholders)';
      args.addAll(typeList.map((t) => t.name));
    }

    final result = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM special_days WHERE $where',
      args,
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// Counts the special days in [from]..[to] grouped by [DayType], for the
  /// Explain report. Weekday-only (Mon–Fri), matching [getSpecialDayCount] so
  /// the figures line up with the attendance-percentage denominator. Types with
  /// no days in range are simply absent from the map. Unknown/legacy type
  /// strings are ignored.
  Future<Map<DayType, int>> getSpecialDayCountsByType(
    DateTime from,
    DateTime to,
  ) async {
    final db = await database;

    final rows = await db.rawQuery(
      "SELECT type, COUNT(*) AS cnt FROM special_days "
      "WHERE date >= ? AND date <= ? AND strftime('%w', date) NOT IN ('0', '6') "
      "GROUP BY type",
      [_fmtDate(from), _fmtDate(to)],
    );

    final counts = <DayType, int>{};
    for (final row in rows) {
      final name = row['type'] as String;
      final match = DayType.values.where((t) => t.name == name);
      if (match.isNotEmpty) counts[match.first] = (row['cnt'] as int?) ?? 0;
    }
    return counts;
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

  /// Every special day (holiday / sick leave / misc leave), newest first.
  Future<List<SpecialDay>> getAllSpecialDays() async {
    final db = await database;
    final rows = await db.query('special_days', orderBy: 'date DESC');
    return rows.map(SpecialDay.fromMap).toList();
  }

  /// Every date with a special day, as a set — lets the holiday importer test
  /// all candidate dates with one query instead of one query per CSV row.
  Future<Set<String>> getAllSpecialDayDates() async {
    final db = await database;
    final rows = await db.query('special_days', columns: ['date']);
    return rows.map((r) => r['date'] as String).toSet();
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

  // ── App settings (key/value preferences) ──────────────────────────────────

  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Clears attendance and special-day data. App preferences in [app_settings]
  /// (e.g. the financial-year start) are intentionally kept.
  Future<void> deleteAllRecords() async {
    final db = await database;
    await db.delete('attendance_records');
    await db.delete('special_days');
    await db.delete('dismissed_holidays');
  }
}

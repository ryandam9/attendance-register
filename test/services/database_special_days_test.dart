import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:attendance_register/models/special_day.dart';

// Opens an in-memory database with the full v3 schema (includes special_days).
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

// ── Helpers that mirror DatabaseService special-day methods ──────────────────

Future<void> _upsert(Database db, SpecialDay day) async {
  final map = day.toMap()..remove('id');
  await db.insert('special_days', map, conflictAlgorithm: ConflictAlgorithm.replace);
}

Future<SpecialDay?> _getForDate(Database db, String date) async {
  final rows = await db.query('special_days', where: 'date = ?', whereArgs: [date]);
  return rows.isEmpty ? null : SpecialDay.fromMap(rows.first);
}

Future<List<SpecialDay>> _getForMonth(Database db, int year, int month) async {
  final start = '$year-${month.toString().padLeft(2, '0')}-01';
  final lastDay = DateTime(year, month + 1, 0).day;
  final end = '$year-${month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';
  final rows = await db.query(
    'special_days',
    where: 'date >= ? AND date <= ?',
    whereArgs: [start, end],
    orderBy: 'date ASC',
  );
  return rows.map(SpecialDay.fromMap).toList();
}

Future<int> _getCount(Database db, DateTime from, DateTime to, {DayType? type}) async {
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

Future<void> _delete(Database db, String date) async {
  await db.delete('special_days', where: 'date = ?', whereArgs: [date]);
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late Database db;

  setUp(() async {
    db = await _openTestDb();
  });

  tearDown(() async {
    await db.close();
  });

  group('Special days CRUD', () {
    test('insert and retrieve a holiday', () async {
      await _upsert(
        db,
        const SpecialDay(date: '2025-01-01', type: DayType.holiday, note: 'New Year'),
      );

      final day = await _getForDate(db, '2025-01-01');

      expect(day, isNotNull);
      expect(day!.date, '2025-01-01');
      expect(day.type, DayType.holiday);
      expect(day.note, 'New Year');
    });

    test('insert and retrieve a sick-leave day without note', () async {
      await _upsert(
        db,
        const SpecialDay(date: '2025-03-10', type: DayType.sickLeave),
      );

      final day = await _getForDate(db, '2025-03-10');

      expect(day, isNotNull);
      expect(day!.type, DayType.sickLeave);
      expect(day.note, isNull);
    });

    test('upsert replaces an existing entry on the same date', () async {
      await _upsert(
        db,
        const SpecialDay(date: '2025-06-15', type: DayType.holiday, note: 'Original'),
      );
      await _upsert(
        db,
        const SpecialDay(date: '2025-06-15', type: DayType.sickLeave, note: 'Replaced'),
      );

      final day = await _getForDate(db, '2025-06-15');

      expect(day!.type, DayType.sickLeave);
      expect(day.note, 'Replaced');

      final rows = await db.query('special_days');
      expect(rows, hasLength(1));
    });

    test('upsert updates the note on the same date and type', () async {
      await _upsert(
        db,
        const SpecialDay(date: '2025-08-15', type: DayType.holiday, note: 'Old note'),
      );
      await _upsert(
        db,
        const SpecialDay(date: '2025-08-15', type: DayType.holiday, note: 'New note'),
      );

      final day = await _getForDate(db, '2025-08-15');

      expect(day!.note, 'New note');
    });

    test('getForDate returns null for a date with no entry', () async {
      final day = await _getForDate(db, '2025-04-01');
      expect(day, isNull);
    });

    test('delete removes the entry', () async {
      await _upsert(db, const SpecialDay(date: '2025-10-02', type: DayType.holiday));
      await _delete(db, '2025-10-02');

      final day = await _getForDate(db, '2025-10-02');

      expect(day, isNull);
    });

    test('delete does not affect other entries', () async {
      await _upsert(db, const SpecialDay(date: '2025-11-01', type: DayType.holiday));
      await _upsert(db, const SpecialDay(date: '2025-11-15', type: DayType.sickLeave));
      await _delete(db, '2025-11-01');

      final remaining = await db.query('special_days');
      expect(remaining, hasLength(1));
      expect(remaining.first['date'], '2025-11-15');
    });
  });

  // ── getSpecialDaysForMonth ────────────────────────────────────────────────

  group('getSpecialDaysForMonth', () {
    setUp(() async {
      for (final entry in const [
        SpecialDay(date: '2025-06-01', type: DayType.holiday),
        SpecialDay(date: '2025-06-15', type: DayType.sickLeave),
        SpecialDay(date: '2025-06-30', type: DayType.holiday),
        SpecialDay(date: '2025-07-01', type: DayType.holiday),
        SpecialDay(date: '2025-05-31', type: DayType.sickLeave),
      ]) {
        await _upsert(db, entry);
      }
    });

    test('returns only days within the requested month', () async {
      final june = await _getForMonth(db, 2025, 6);

      expect(june, hasLength(3));
      expect(june.map((d) => d.date), containsAll(['2025-06-01', '2025-06-15', '2025-06-30']));
    });

    test('excludes days from the adjacent months', () async {
      final june = await _getForMonth(db, 2025, 6);

      expect(june.map((d) => d.date), isNot(contains('2025-07-01')));
      expect(june.map((d) => d.date), isNot(contains('2025-05-31')));
    });

    test('results are ordered by date ascending', () async {
      final june = await _getForMonth(db, 2025, 6);

      expect(june[0].date, '2025-06-01');
      expect(june[1].date, '2025-06-15');
      expect(june[2].date, '2025-06-30');
    });

    test('returns empty list for a month with no entries', () async {
      final august = await _getForMonth(db, 2025, 8);
      expect(august, isEmpty);
    });

    test('first and last day of month are included', () async {
      final june = await _getForMonth(db, 2025, 6);
      final dates = june.map((d) => d.date).toList();
      expect(dates, contains('2025-06-01'));
      expect(dates, contains('2025-06-30'));
    });
  });

  // ── getSpecialDayCount ────────────────────────────────────────────────────

  group('getSpecialDayCount', () {
    setUp(() async {
      for (final entry in const [
        SpecialDay(date: '2025-06-02', type: DayType.holiday),
        SpecialDay(date: '2025-06-09', type: DayType.holiday),
        SpecialDay(date: '2025-06-16', type: DayType.sickLeave),
        SpecialDay(date: '2025-07-04', type: DayType.holiday),
      ]) {
        await _upsert(db, entry);
      }
    });

    test('counts all types within a range', () async {
      final count = await _getCount(
        db,
        DateTime(2025, 6, 1),
        DateTime(2025, 6, 30),
      );
      expect(count, 3);
    });

    test('counts only holidays within a range', () async {
      final count = await _getCount(
        db,
        DateTime(2025, 6, 1),
        DateTime(2025, 6, 30),
        type: DayType.holiday,
      );
      expect(count, 2);
    });

    test('counts only sick-leave days within a range', () async {
      final count = await _getCount(
        db,
        DateTime(2025, 6, 1),
        DateTime(2025, 6, 30),
        type: DayType.sickLeave,
      );
      expect(count, 1);
    });

    test('returns 0 when no matching entries exist', () async {
      final count = await _getCount(
        db,
        DateTime(2025, 8, 1),
        DateTime(2025, 8, 31),
      );
      expect(count, 0);
    });

    test('entries outside the range are excluded', () async {
      final count = await _getCount(
        db,
        DateTime(2025, 6, 1),
        DateTime(2025, 6, 30),
      );
      // 2025-07-04 is outside the range
      expect(count, 3);
    });

    test('boundary dates are inclusive', () async {
      final count = await _getCount(
        db,
        DateTime(2025, 6, 2),
        DateTime(2025, 6, 16),
      );
      expect(count, 3); // 06-02, 06-09, 06-16
    });
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_register/models/special_day.dart';

void main() {
  group('SpecialDay', () {
    test('toMap includes all fields for holiday with note', () {
      const day = SpecialDay(
        id: 1,
        date: '2025-01-01',
        type: DayType.holiday,
        note: 'New Year',
      );

      final map = day.toMap();

      expect(map['id'], 1);
      expect(map['date'], '2025-01-01');
      expect(map['type'], 'holiday');
      expect(map['note'], 'New Year');
    });

    test('toMap with null note stores null', () {
      const day = SpecialDay(
        date: '2025-01-01',
        type: DayType.sickLeave,
      );

      expect(day.toMap()['note'], isNull);
    });

    test('toMap encodes DayType.holiday as the string "holiday"', () {
      const day = SpecialDay(date: '2025-01-01', type: DayType.holiday);
      expect(day.toMap()['type'], 'holiday');
    });

    test('toMap encodes DayType.sickLeave as the string "sickLeave"', () {
      const day = SpecialDay(date: '2025-01-01', type: DayType.sickLeave);
      expect(day.toMap()['type'], 'sickLeave');
    });

    test('fromMap round-trips holiday with note', () {
      const original = SpecialDay(
        id: 5,
        date: '2025-12-25',
        type: DayType.holiday,
        note: 'Christmas',
      );

      final restored = SpecialDay.fromMap(original.toMap());

      expect(restored.id, 5);
      expect(restored.date, '2025-12-25');
      expect(restored.type, DayType.holiday);
      expect(restored.note, 'Christmas');
    });

    test('fromMap round-trips sickLeave without note', () {
      const original = SpecialDay(
        id: 2,
        date: '2025-03-10',
        type: DayType.sickLeave,
      );

      final restored = SpecialDay.fromMap(original.toMap());

      expect(restored.id, 2);
      expect(restored.date, '2025-03-10');
      expect(restored.type, DayType.sickLeave);
      expect(restored.note, isNull);
    });

    test('fromMap with null id returns null id', () {
      final map = {
        'id': null,
        'date': '2025-06-01',
        'type': 'holiday',
        'note': null,
      };

      final day = SpecialDay.fromMap(map);

      expect(day.id, isNull);
    });

    test('fromMap handles null note column from DB', () {
      final map = {
        'id': 3,
        'date': '2025-05-01',
        'type': 'sickLeave',
        'note': null,
      };

      final day = SpecialDay.fromMap(map);

      expect(day.note, isNull);
    });

    test('DayType enum has exactly holiday and sickLeave', () {
      expect(DayType.values, hasLength(2));
      expect(DayType.values, containsAll([DayType.holiday, DayType.sickLeave]));
    });

    test('toMap then fromMap preserves null id', () {
      const day = SpecialDay(date: '2025-07-04', type: DayType.holiday);
      final restored = SpecialDay.fromMap(day.toMap());
      expect(restored.id, isNull);
    });
  });
}

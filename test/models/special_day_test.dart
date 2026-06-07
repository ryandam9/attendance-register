import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_register/models/special_day.dart';

void main() {
  group('SpecialDay', () {
    test('defaults to a manual source', () {
      const day = SpecialDay(date: '2026-01-01', type: DayType.holiday);
      expect(day.source, DaySource.manual);
    });

    test('toMap / fromMap round-trip preserves source', () {
      const day = SpecialDay(
        date: '2026-01-01',
        type: DayType.holiday,
        note: "New Year's Day",
        source: DaySource.auto,
      );
      final restored = SpecialDay.fromMap(day.toMap());

      expect(restored.date, day.date);
      expect(restored.type, DayType.holiday);
      expect(restored.note, "New Year's Day");
      expect(restored.source, DaySource.auto);
    });

    test('fromMap treats a missing source (pre-v4 rows) as manual', () {
      final restored = SpecialDay.fromMap({
        'id': 1,
        'date': '2026-01-01',
        'type': 'holiday',
        'note': null,
        // no 'source' key — as read back from an old database row
      });
      expect(restored.source, DaySource.manual);
    });

    test('annual and carer\'s leave round-trip through their enum name', () {
      for (final type in [DayType.annualLeave, DayType.carersLeave]) {
        const date = '2026-06-08';
        final restored = SpecialDay.fromMap(
          SpecialDay(date: date, type: type).toMap(),
        );
        expect(restored.type, type);
        expect(DayType.values.byName(type.name), type);
      }
    });
  });

  group('excludedFromAttendanceDenominator', () {
    test('excludes every leave type but keeps notAttended in the denominator',
        () {
      expect(excludedFromAttendanceDenominator, contains(DayType.holiday));
      expect(excludedFromAttendanceDenominator, contains(DayType.sickLeave));
      expect(excludedFromAttendanceDenominator, contains(DayType.annualLeave));
      expect(excludedFromAttendanceDenominator, contains(DayType.carersLeave));
      // A normal working day you skipped must stay in the denominator so it
      // lowers your percentage.
      expect(
        excludedFromAttendanceDenominator,
        isNot(contains(DayType.notAttended)),
      );
    });
  });
}

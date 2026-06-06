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
  });
}

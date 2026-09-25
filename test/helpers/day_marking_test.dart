import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_register/helpers/day_marking.dart';

void main() {
  group('isPlannedDay', () {
    test('today is not planned, whatever the time of day it carries', () {
      final now = DateTime.now();
      expect(isPlannedDay(DateTime(now.year, now.month, now.day)), isFalse);
      // A day-precision "today" plus a late time must still read as today —
      // comparing against DateTime.now() without normalising would call this
      // one planned for most of the day.
      expect(
        isPlannedDay(DateTime(now.year, now.month, now.day, 23, 59)),
        isFalse,
      );
    });

    test('yesterday is not planned', () {
      expect(
        isPlannedDay(DateTime.now().subtract(const Duration(days: 1))),
        isFalse,
      );
    });

    test('tomorrow and beyond are planned', () {
      final now = DateTime.now();
      expect(isPlannedDay(DateTime(now.year, now.month, now.day + 1)), isTrue);
      expect(isPlannedDay(DateTime(now.year + 1, now.month, now.day)), isTrue);
    });
  });
}

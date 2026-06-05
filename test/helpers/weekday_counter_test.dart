import 'package:flutter_test/flutter_test.dart';

// Local mirror of the private _countWeekdays function in attendance_provider.dart.
// Tests here protect the weekday-counting business logic independently of the provider.
int _countWeekdays(DateTime start, DateTime end) {
  int count = 0;
  DateTime current = DateTime(start.year, start.month, start.day);
  final last = DateTime(end.year, end.month, end.day);
  while (!current.isAfter(last)) {
    final wd = current.weekday;
    if (wd != DateTime.saturday && wd != DateTime.sunday) count++;
    current = current.add(const Duration(days: 1));
  }
  return count;
}

void main() {
  group('_countWeekdays', () {
    test('single Monday counts as 1', () {
      // 2025-01-06 is a Monday
      final d = DateTime(2025, 1, 6);
      expect(_countWeekdays(d, d), 1);
    });

    test('single Saturday counts as 0', () {
      // 2025-01-04 is a Saturday
      final d = DateTime(2025, 1, 4);
      expect(_countWeekdays(d, d), 0);
    });

    test('single Sunday counts as 0', () {
      // 2025-01-05 is a Sunday
      final d = DateTime(2025, 1, 5);
      expect(_countWeekdays(d, d), 0);
    });

    test('Mon–Fri week counts as 5', () {
      // 2025-01-06 Mon to 2025-01-10 Fri
      expect(
        _countWeekdays(DateTime(2025, 1, 6), DateTime(2025, 1, 10)),
        5,
      );
    });

    test('Mon–Sun week counts as 5', () {
      // 2025-01-06 Mon to 2025-01-12 Sun
      expect(
        _countWeekdays(DateTime(2025, 1, 6), DateTime(2025, 1, 12)),
        5,
      );
    });

    test('Sat–Sun weekend counts as 0', () {
      expect(
        _countWeekdays(DateTime(2025, 1, 4), DateTime(2025, 1, 5)),
        0,
      );
    });

    test('January 2025 has 23 weekdays', () {
      // 2025-01-01 is Wednesday; 5 Wednesdays, 5 Thursdays, 5 Fridays,
      // 4 Mondays, 4 Tuesdays = 23 total
      expect(
        _countWeekdays(DateTime(2025, 1, 1), DateTime(2025, 1, 31)),
        23,
      );
    });

    test('February 2025 has 20 weekdays', () {
      // 2025-02-01 is Saturday; 4 of each Mon–Fri = 20 total
      expect(
        _countWeekdays(DateTime(2025, 2, 1), DateTime(2025, 2, 28)),
        20,
      );
    });

    test('full year 2025 has 261 weekdays', () {
      // 2025 is not a leap year (365 days); 261 weekdays
      expect(
        _countWeekdays(DateTime(2025, 1, 1), DateTime(2025, 12, 31)),
        261,
      );
    });

    test('start == end on a Friday counts as 1', () {
      // 2025-01-10 is a Friday
      final d = DateTime(2025, 1, 10);
      expect(_countWeekdays(d, d), 1);
    });

    test('range spanning two months is counted correctly', () {
      // 2025-01-27 Mon to 2025-02-07 Fri = 2 full Mon-Fri weeks = 10
      expect(
        _countWeekdays(DateTime(2025, 1, 27), DateTime(2025, 2, 7)),
        10,
      );
    });

    test('single-day range on a Wednesday counts as 1', () {
      // 2025-01-01 is Wednesday
      final d = DateTime(2025, 1, 1);
      expect(_countWeekdays(d, d), 1);
    });
  });
}

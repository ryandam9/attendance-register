import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_register/models/attendance_breakdown.dart';
import 'package:attendance_register/models/special_day.dart';

void main() {
  group('countWeekdays', () {
    test('counts only Mon–Fri in an inclusive range', () {
      // Mon 2026-06-01 .. Sun 2026-06-07 -> 5 weekdays.
      expect(countWeekdays(DateTime(2026, 6, 1), DateTime(2026, 6, 7)), 5);
    });

    test('a single weekend day is zero', () {
      // 2026-06-06 is a Saturday.
      expect(countWeekdays(DateTime(2026, 6, 6), DateTime(2026, 6, 6)), 0);
    });
  });

  group('AttendanceBreakdown', () {
    AttendanceBreakdown make({
      int weekdays = 22,
      int officeDays = 10,
      Map<DayType, int>? counts,
    }) =>
        AttendanceBreakdown(
          weekdays: weekdays,
          officeDays: officeDays,
          specialDayCounts: counts ?? const {},
        );

    test('only leave types are subtracted from the denominator', () {
      final b = make(weekdays: 20, officeDays: 8, counts: const {
        DayType.holiday: 1,
        DayType.sickLeave: 1,
        DayType.annualLeave: 1,
        DayType.carersLeave: 1,
        DayType.miscLeave: 1,
        DayType.workFromHome: 3, // stays in the denominator
      });
      expect(b.excludedDays, 5);
      expect(b.eligibleWorkingDays, 15); // 20 - 5
    });

    test('return-to-office percentage divides office days by eligible days', () {
      final b = make(weekdays: 20, officeDays: 8, counts: const {
        DayType.annualLeave: 4, // 20 - 4 = 16 eligible
      });
      expect(b.returnToOfficePercentage, closeTo(50.0, 1e-9)); // 8 / 16
    });

    test('work-from-home lowers the percentage (stays in denominator)', () {
      final office = make(weekdays: 10, officeDays: 5, counts: const {});
      final withWfh = make(weekdays: 10, officeDays: 5, counts: const {
        DayType.workFromHome: 5,
      });
      // WFH does not change the denominator, so the percentage is unchanged at
      // 50% — confirming WFH days you didn't attend the office still count
      // against you rather than being excluded.
      expect(office.returnToOfficePercentage, 50.0);
      expect(withWfh.returnToOfficePercentage, 50.0);
      expect(withWfh.eligibleWorkingDays, 10);
    });

    test('percentage is null when there are no eligible working days', () {
      final b = make(weekdays: 5, officeDays: 0, counts: const {
        DayType.holiday: 5,
      });
      expect(b.eligibleWorkingDays, 0);
      expect(b.returnToOfficePercentage, isNull);
    });

    test('percentage is clamped to 100', () {
      final b = make(weekdays: 5, officeDays: 9, counts: const {});
      expect(b.returnToOfficePercentage, 100.0);
    });
  });
}

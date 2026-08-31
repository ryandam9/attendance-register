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
      int remaining = 0,
    }) => AttendanceBreakdown(
      weekdays: weekdays,
      officeDays: officeDays,
      specialDayCounts: counts ?? const {},
      remainingEligibleDays: remaining,
    );

    test('only leave types are subtracted from the denominator', () {
      final b = make(
        weekdays: 20,
        officeDays: 8,
        counts: const {
          DayType.holiday: 1,
          DayType.sickLeave: 1,
          DayType.annualLeave: 1,
          DayType.carersLeave: 1,
          DayType.miscLeave: 1,
          DayType.workFromHome: 3, // stays in the denominator
        },
      );
      expect(b.excludedDays, 5);
      expect(b.eligibleWorkingDays, 15); // 20 - 5
    });

    test(
      'return-to-office percentage divides office days by eligible days',
      () {
        final b = make(
          weekdays: 20,
          officeDays: 8,
          counts: const {
            DayType.annualLeave: 4, // 20 - 4 = 16 eligible
          },
        );
        expect(b.returnToOfficePercentage, closeTo(50.0, 1e-9)); // 8 / 16
      },
    );

    test('work-from-home lowers the percentage (stays in denominator)', () {
      final office = make(weekdays: 10, officeDays: 5, counts: const {});
      final withWfh = make(
        weekdays: 10,
        officeDays: 5,
        counts: const {DayType.workFromHome: 5},
      );
      // WFH does not change the denominator, so the percentage is unchanged at
      // 50% — confirming WFH days you didn't attend the office still count
      // against you rather than being excluded.
      expect(office.returnToOfficePercentage, 50.0);
      expect(withWfh.returnToOfficePercentage, 50.0);
      expect(withWfh.eligibleWorkingDays, 10);
    });

    test('percentage is null when there are no eligible working days', () {
      final b = make(
        weekdays: 5,
        officeDays: 0,
        counts: const {DayType.holiday: 5},
      );
      expect(b.eligibleWorkingDays, 0);
      expect(b.returnToOfficePercentage, isNull);
    });

    test('percentage is clamped to 100', () {
      final b = make(weekdays: 5, officeDays: 9, counts: const {});
      expect(b.returnToOfficePercentage, 100.0);
    });

    test('a single office day is a share of the whole month, not 100%', () {
      // Regression: the Insights gauge divided by the weekdays that had
      // elapsed, so checking in on the 1st read as 100%. The denominator is
      // the whole month — Tue 1 Sep 2026 to Wed 30 Sep 2026 is 22 weekdays —
      // so one office day is 4.5%, the same figure the home dashboard shows.
      final sep = countWeekdays(DateTime(2026, 9, 1), DateTime(2026, 9, 30));
      expect(sep, 22);

      final b = make(weekdays: sep, officeDays: 1, counts: const {});
      expect(b.eligibleWorkingDays, 22);
      expect(b.returnToOfficePercentage, closeTo(4.5454, 1e-3));
    });

    test('office days to target counts up to the next whole day', () {
      // 50% of 22 eligible days is 11; with 6 recorded, 5 are still needed.
      final b = make(weekdays: 22, officeDays: 6, remaining: 10);
      expect(b.officeDaysToTarget(50), 5);
      // Already past the target, so nothing more is needed (never negative).
      expect(make(weekdays: 22, officeDays: 20).officeDaysToTarget(50), 0);
    });

    test('a target needing more days than are left is unreachable', () {
      // August 2026 as the user saw it: 29%, five office days short, and the
      // month already over — nothing is left to earn them with.
      final over = make(weekdays: 21, officeDays: 6, remaining: 0);
      expect(over.officeDaysToTarget(50), 5);
      expect(over.targetReachable(50), isFalse);
      expect(over.isFinal, isTrue);

      // Mid-month with only two working days left it is out of reach too,
      // even though the period has not ended.
      final tooLate = make(weekdays: 21, officeDays: 6, remaining: 2);
      expect(tooLate.targetReachable(50), isFalse);
      expect(tooLate.isFinal, isFalse);

      // Exactly enough days left to close the gap — still reachable.
      final justEnough = make(weekdays: 21, officeDays: 6, remaining: 5);
      expect(justEnough.targetReachable(50), isTrue);
    });

    test('a met target is reachable even with no days left', () {
      final b = make(weekdays: 20, officeDays: 15, remaining: 0);
      expect(b.officeDaysToTarget(50), 0);
      expect(b.targetReachable(50), isTrue);
    });

    test('weekend office days do not affect the percentage', () {
      const withWeekend = AttendanceBreakdown(
        weekdays: 10,
        officeDays: 5,
        weekendOfficeDays: 2,
        specialDayCounts: {},
        remainingEligibleDays: 0,
      );
      expect(withWeekend.returnToOfficePercentage, 50.0); // 5 / 10
      expect(withWeekend.weekendOfficeDays, 2);
    });
  });
}

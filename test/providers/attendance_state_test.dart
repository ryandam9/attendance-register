import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_register/models/attendance_record.dart';
import 'package:attendance_register/providers/attendance_provider.dart';

void main() {
  group('AttendanceState', () {
    // ── Default values ────────────────────────────────────────────────────────

    group('defaults', () {
      test('initial state has all-zero counts', () {
        const state = AttendanceState();

        expect(state.records, isEmpty);
        expect(state.monthlyCount, 0);
        expect(state.yearlyCount, 0);
        expect(state.monthlyWeekdays, 0);
        expect(state.yearlyWeekdays, 0);
        expect(state.monthlyHolidayCount, 0);
        expect(state.monthlySickLeaveCount, 0);
        expect(state.yearlyHolidayCount, 0);
        expect(state.yearlySickLeaveCount, 0);
        expect(state.loading, false);
      });

      test('monthlyPercentage is null when weekdays are zero', () {
        const state = AttendanceState();
        expect(state.monthlyPercentage, isNull);
      });

      test('yearlyPercentage is null when weekdays are zero', () {
        const state = AttendanceState();
        expect(state.yearlyPercentage, isNull);
      });
    });

    // ── attendanceDates ───────────────────────────────────────────────────────

    group('attendanceDates', () {
      final ts = DateTime(2025, 6, 1);

      test('empty records yields empty set', () {
        const state = AttendanceState();
        expect(state.attendanceDates, isEmpty);
      });

      test('returns a DateTime for each record date', () {
        final state = AttendanceState(
          records: [
            AttendanceRecord(
              date: '2025-06-01',
              officeLocationId: 1,
              timestamp: ts,
            ),
            AttendanceRecord(
              date: '2025-06-15',
              officeLocationId: 1,
              timestamp: ts,
            ),
          ],
        );

        expect(state.attendanceDates, hasLength(2));
        expect(state.attendanceDates, contains(DateTime(2025, 6, 1)));
        expect(state.attendanceDates, contains(DateTime(2025, 6, 15)));
      });

      test('deduplicates the same date across different offices', () {
        final state = AttendanceState(
          records: [
            AttendanceRecord(
              date: '2025-06-15',
              officeLocationId: 1,
              timestamp: ts,
            ),
            AttendanceRecord(
              date: '2025-06-15',
              officeLocationId: 2,
              timestamp: ts,
            ),
          ],
        );

        expect(state.attendanceDates, hasLength(1));
        expect(state.attendanceDates, contains(DateTime(2025, 6, 15)));
      });

      test('parses year, month, and day correctly from YYYY-MM-DD', () {
        final state = AttendanceState(
          records: [
            AttendanceRecord(
              date: '2025-12-31',
              officeLocationId: 1,
              timestamp: ts,
            ),
          ],
        );

        final date = state.attendanceDates.first;
        expect(date.year, 2025);
        expect(date.month, 12);
        expect(date.day, 31);
      });
    });

    // ── monthlyPercentage ─────────────────────────────────────────────────────

    group('monthlyPercentage', () {
      test('returns null when holidays exhaust all weekdays (base == 0)', () {
        const state = AttendanceState(
          monthlyWeekdays: 5,
          monthlyHolidayCount: 5,
          monthlyCount: 3,
        );

        expect(state.monthlyPercentage, isNull);
      });

      test('returns null when special days exceed weekdays (base < 0)', () {
        const state = AttendanceState(
          monthlyWeekdays: 4,
          monthlyHolidayCount: 3,
          monthlySickLeaveCount: 2,
          monthlyCount: 2,
        );

        expect(state.monthlyPercentage, isNull);
      });

      test('calculates 50 % correctly', () {
        const state = AttendanceState(
          monthlyCount: 10,
          monthlyWeekdays: 20,
        );

        expect(state.monthlyPercentage, 50.0);
      });

      test('holidays reduce the denominator', () {
        // base = 20 - 2 = 18; 9 / 18 * 100 = 50 %
        const state = AttendanceState(
          monthlyCount: 9,
          monthlyWeekdays: 20,
          monthlyHolidayCount: 2,
        );

        expect(state.monthlyPercentage, 50.0);
      });

      test('sick leave reduces the denominator', () {
        // base = 21 - 3 = 18; 9 / 18 * 100 = 50 %
        const state = AttendanceState(
          monthlyCount: 9,
          monthlyWeekdays: 21,
          monthlySickLeaveCount: 3,
        );

        expect(state.monthlyPercentage, 50.0);
      });

      test('both holidays and sick leave reduce the denominator', () {
        // base = 22 - 2 - 4 = 16; 8 / 16 * 100 = 50 %
        const state = AttendanceState(
          monthlyCount: 8,
          monthlyWeekdays: 22,
          monthlyHolidayCount: 2,
          monthlySickLeaveCount: 4,
        );

        expect(state.monthlyPercentage, 50.0);
      });

      test('returns 100 when all available days are attended', () {
        const state = AttendanceState(
          monthlyCount: 18,
          monthlyWeekdays: 20,
          monthlyHolidayCount: 2,
        );

        expect(state.monthlyPercentage, 100.0);
      });

      test('clamps to 100 when count exceeds the base', () {
        const state = AttendanceState(
          monthlyCount: 25,
          monthlyWeekdays: 18,
        );

        expect(state.monthlyPercentage, 100.0);
      });

      test('returns 0.0 when count is 0 but base is positive', () {
        const state = AttendanceState(
          monthlyCount: 0,
          monthlyWeekdays: 20,
        );

        expect(state.monthlyPercentage, 0.0);
      });

      test('fractional percentage rounds correctly', () {
        // 1 / 3 * 100 ≈ 33.33...
        const state = AttendanceState(
          monthlyCount: 1,
          monthlyWeekdays: 3,
        );

        expect(state.monthlyPercentage, closeTo(33.33, 0.01));
      });
    });

    // ── yearlyPercentage ──────────────────────────────────────────────────────

    group('yearlyPercentage', () {
      test('returns null when no weekdays', () {
        const state = AttendanceState(yearlyWeekdays: 0);
        expect(state.yearlyPercentage, isNull);
      });

      test('returns null when holidays cover all weekdays', () {
        const state = AttendanceState(
          yearlyWeekdays: 260,
          yearlyHolidayCount: 260,
        );

        expect(state.yearlyPercentage, isNull);
      });

      test('calculates 50 % correctly over a full year', () {
        const state = AttendanceState(
          yearlyCount: 130,
          yearlyWeekdays: 260,
        );

        expect(state.yearlyPercentage, 50.0);
      });

      test('yearly holidays and sick leave both reduce the denominator', () {
        // base = 260 - 10 - 14 = 236; 118 / 236 * 100 = 50 %
        const state = AttendanceState(
          yearlyCount: 118,
          yearlyWeekdays: 260,
          yearlyHolidayCount: 10,
          yearlySickLeaveCount: 14,
        );

        expect(state.yearlyPercentage, 50.0);
      });

      test('clamps yearly percentage to 100', () {
        const state = AttendanceState(
          yearlyCount: 300,
          yearlyWeekdays: 260,
        );

        expect(state.yearlyPercentage, 100.0);
      });

      test('returns 0.0 when yearly count is 0', () {
        const state = AttendanceState(
          yearlyCount: 0,
          yearlyWeekdays: 260,
        );

        expect(state.yearlyPercentage, 0.0);
      });
    });
  });
}

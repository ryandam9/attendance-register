import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_register/models/special_day.dart';
import 'package:attendance_register/providers/special_day_provider.dart';

void main() {
  group('SpecialDayState', () {
    test('empty state has no holiday or sick-leave dates', () {
      const state = SpecialDayState();

      expect(state.holidayDates, isEmpty);
      expect(state.sickLeaveDates, isEmpty);
    });

    test('loading defaults to false', () {
      const state = SpecialDayState();
      expect(state.loading, isFalse);
    });

    // ── holidayDates ──────────────────────────────────────────────────────────

    group('holidayDates', () {
      test('returns only holiday-type days', () {
        const state = SpecialDayState(days: [
          SpecialDay(date: '2025-01-01', type: DayType.holiday),
          SpecialDay(date: '2025-01-10', type: DayType.sickLeave),
          SpecialDay(date: '2025-12-25', type: DayType.holiday),
        ]);

        expect(state.holidayDates, hasLength(2));
        expect(state.holidayDates, contains(DateTime(2025, 1, 1)));
        expect(state.holidayDates, contains(DateTime(2025, 12, 25)));
        expect(state.holidayDates, isNot(contains(DateTime(2025, 1, 10))));
      });

      test('returns empty set when all days are sick leave', () {
        const state = SpecialDayState(days: [
          SpecialDay(date: '2025-02-14', type: DayType.sickLeave),
        ]);

        expect(state.holidayDates, isEmpty);
      });

      test('parses date string into correct DateTime components', () {
        const state = SpecialDayState(days: [
          SpecialDay(date: '2025-07-04', type: DayType.holiday),
        ]);

        final date = state.holidayDates.first;
        expect(date.year, 2025);
        expect(date.month, 7);
        expect(date.day, 4);
      });
    });

    // ── sickLeaveDates ────────────────────────────────────────────────────────

    group('sickLeaveDates', () {
      test('returns only sick-leave-type days', () {
        const state = SpecialDayState(days: [
          SpecialDay(date: '2025-01-01', type: DayType.holiday),
          SpecialDay(date: '2025-03-05', type: DayType.sickLeave),
          SpecialDay(date: '2025-03-06', type: DayType.sickLeave),
        ]);

        expect(state.sickLeaveDates, hasLength(2));
        expect(state.sickLeaveDates, contains(DateTime(2025, 3, 5)));
        expect(state.sickLeaveDates, contains(DateTime(2025, 3, 6)));
        expect(state.sickLeaveDates, isNot(contains(DateTime(2025, 1, 1))));
      });

      test('returns empty set when all days are holidays', () {
        const state = SpecialDayState(days: [
          SpecialDay(date: '2025-12-25', type: DayType.holiday),
        ]);

        expect(state.sickLeaveDates, isEmpty);
      });

      test('parses date string into correct DateTime components', () {
        const state = SpecialDayState(days: [
          SpecialDay(date: '2025-09-15', type: DayType.sickLeave),
        ]);

        final date = state.sickLeaveDates.first;
        expect(date.year, 2025);
        expect(date.month, 9);
        expect(date.day, 15);
      });
    });

    test('mixed list splits correctly across both sets', () {
      const state = SpecialDayState(days: [
        SpecialDay(date: '2025-01-01', type: DayType.holiday),
        SpecialDay(date: '2025-01-06', type: DayType.sickLeave),
        SpecialDay(date: '2025-05-01', type: DayType.holiday),
        SpecialDay(date: '2025-05-02', type: DayType.sickLeave),
      ]);

      expect(state.holidayDates, hasLength(2));
      expect(state.sickLeaveDates, hasLength(2));
    });
  });
}

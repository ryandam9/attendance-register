import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/special_day.dart';
import '../services/database_service.dart';

class SpecialDayState {
  final List<SpecialDay> days;
  final bool loading;

  const SpecialDayState({this.days = const [], this.loading = false});

  Set<DateTime> get holidayDates => days
      .where((d) => d.type == DayType.holiday)
      .map((d) => DateTime.parse(d.date))
      .toSet();

  Set<DateTime> get sickLeaveDates => days
      .where((d) => d.type == DayType.sickLeave)
      .map((d) => DateTime.parse(d.date))
      .toSet();

  Set<DateTime> get notAttendedDates => days
      .where((d) => d.type == DayType.notAttended)
      .map((d) => DateTime.parse(d.date))
      .toSet();
}

class SpecialDayNotifier extends Notifier<SpecialDayState> {
  @override
  SpecialDayState build() => const SpecialDayState();

  Future<void> loadForMonth(int year, int month) async {
    state = SpecialDayState(days: state.days, loading: true);
    final days =
        await DatabaseService.instance.getSpecialDaysForMonth(year, month);
    state = SpecialDayState(days: days);
  }

  Future<void> saveDay(SpecialDay day) async {
    await DatabaseService.instance.upsertSpecialDay(day);
    final target = DateTime.parse(day.date);
    await loadForMonth(target.year, target.month);
  }

  /// Removes the special day for [date]. When [dismiss] is true the date is also
  /// recorded as a dismissed holiday so the importer will not re-add it — used
  /// when the user deletes an auto-imported public holiday.
  Future<void> deleteDay(String date, {bool dismiss = false}) async {
    await DatabaseService.instance.deleteSpecialDay(date);
    if (dismiss) {
      await DatabaseService.instance.dismissHoliday(date);
    }
    state = SpecialDayState(
      days: state.days.where((d) => d.date != date).toList(),
    );
  }
}

final specialDayProvider =
    NotifierProvider<SpecialDayNotifier, SpecialDayState>(
  SpecialDayNotifier.new,
);

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/attendance_record.dart';
import '../models/office_location.dart';
import '../models/special_day.dart';
import '../providers/attendance_provider.dart';
import '../providers/special_day_provider.dart';
import 'day_type_helper.dart';

/// Saving and removing a day's status, shared by the full day-entry screen and
/// the quick-mark bottom sheet so the replace-conflicting-entry rules live in
/// exactly one place.

/// Saves [status] for [dateKey] (YYYY-MM-DD), replacing any conflicting entry:
/// marking attendance removes a special day and vice versa.
Future<void> saveDayStatus(
  WidgetRef ref, {
  required OfficeLocation office,
  required String dateKey,
  required DayStatus status,
  String? note,
  AttendanceRecord? existingRecord,
  SpecialDay? existingSpecial,
}) async {
  final attendance = ref.read(attendanceProvider.notifier);
  final special = ref.read(specialDayProvider.notifier);

  if (status == DayStatus.attended) {
    if (existingSpecial != null) await special.deleteDay(dateKey);
    await attendance.saveRecord(office.id!, dateKey, reason: note);
  } else {
    if (existingRecord != null) {
      await attendance.deleteRecord(dateKey, office.id!);
    }
    await special.saveDay(SpecialDay(
      id: existingSpecial?.id,
      date: dateKey,
      type: status.dayType,
      note: note,
    ));
  }
}

/// Removes whatever is recorded on [dateKey]. Removing an auto-imported public
/// holiday also dismisses it so the importer doesn't resurrect it on the next
/// sync.
Future<void> removeDayEntry(
  WidgetRef ref, {
  required OfficeLocation office,
  required String dateKey,
  AttendanceRecord? existingRecord,
  SpecialDay? existingSpecial,
}) async {
  if (existingRecord != null) {
    await ref
        .read(attendanceProvider.notifier)
        .deleteRecord(dateKey, office.id!);
  }
  if (existingSpecial != null) {
    final wasAutoHoliday = existingSpecial.type == DayType.holiday &&
        existingSpecial.source == DaySource.auto;
    await ref
        .read(specialDayProvider.notifier)
        .deleteDay(dateKey, dismiss: wasAutoHoliday);
  }
}

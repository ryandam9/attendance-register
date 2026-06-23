import 'package:flutter_riverpod/flutter_riverpod.dart';

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
///
/// The conflicting entry is removed unconditionally rather than only when the
/// caller's snapshot says one exists: snapshots are taken when the sheet
/// opens, and a background geofence event can insert an auto check-in in the
/// meantime. Trusting a stale null here used to leave the day with both an
/// "Auto check-in" attendance record and a special day (e.g. Work from Home)
/// at once.
Future<void> saveDayStatus(
  WidgetRef ref, {
  required OfficeLocation office,
  required String dateKey,
  required DayStatus status,
  String? note,
  SpecialDay? existingSpecial,
}) async {
  final attendance = ref.read(attendanceProvider.notifier);
  final special = ref.read(specialDayProvider.notifier);

  if (status == DayStatus.attended) {
    await special.deleteDay(dateKey);
    await attendance.saveRecord(office.id!, dateKey, reason: note);
  } else {
    await attendance.deleteRecord(dateKey, office.id!);
    await special.saveDay(
      SpecialDay(
        id: existingSpecial?.id,
        date: dateKey,
        type: status.dayType,
        note: note,
      ),
    );
  }
}

/// Removes whatever is recorded on [dateKey]. Removing an auto-imported public
/// holiday also dismisses it so the importer doesn't resurrect it on the next
/// sync.
Future<void> removeDayEntry(
  WidgetRef ref, {
  required OfficeLocation office,
  required String dateKey,
  SpecialDay? existingSpecial,
}) async {
  // Unconditional for the same stale-snapshot reason as saveDayStatus — an
  // auto check-in inserted after the sheet opened must not survive a Remove.
  // Deleting also dismisses auto check-in for the day, so blanking today
  // sticks even while the user is still inside the office radius.
  await ref.read(attendanceProvider.notifier).deleteRecord(dateKey, office.id!);
  if (existingSpecial != null) {
    final wasAutoHoliday =
        existingSpecial.type == DayType.holiday &&
        existingSpecial.source == DaySource.auto;
    await ref
        .read(specialDayProvider.notifier)
        .deleteDay(dateKey, dismiss: wasAutoHoliday);
  }
}

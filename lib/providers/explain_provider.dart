import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/attendance_breakdown.dart';
import '../services/database_service.dart';

/// Identifies a breakdown request: which office, over which inclusive range.
/// A record (value type) so Riverpod's family caches by structural equality.
typedef BreakdownArgs = ({int officeId, DateTime start, DateTime end});

/// Computes the [AttendanceBreakdown] for a given office and date range used by
/// the Explain page — office days, per-type leave counts, and the weekday total
/// the percentage is derived from.
///
/// `autoDispose` so the figures are recomputed fresh each time the Explain page
/// is reopened, picking up any days edited while it was closed.
final breakdownProvider =
    FutureProvider.autoDispose.family<AttendanceBreakdown, BreakdownArgs>((ref, args) async {
  final db = DatabaseService.instance;

  // Weekday-only numerator (matches the weekday-built denominator); weekend
  // check-ins are reported separately and excluded from the maths.
  final officeWeekdays = await db.getAttendanceCount(
    args.officeId,
    from: args.start,
    to: args.end,
    weekdaysOnly: true,
  );
  final officeTotal = await db.getAttendanceCount(
    args.officeId,
    from: args.start,
    to: args.end,
  );
  final specialDayCounts =
      await db.getSpecialDayCountsByType(args.start, args.end);

  return AttendanceBreakdown(
    weekdays: countWeekdays(args.start, args.end),
    officeDays: officeWeekdays,
    weekendOfficeDays: officeTotal - officeWeekdays,
    specialDayCounts: specialDayCounts,
  );
});

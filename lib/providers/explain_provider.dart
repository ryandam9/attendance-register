import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/attendance_breakdown.dart';
import '../models/special_day.dart';
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
final breakdownProvider = FutureProvider.autoDispose
    .family<AttendanceBreakdown, BreakdownArgs>((ref, args) async {
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
      final specialDayCounts = await db.getSpecialDayCountsByType(
        args.start,
        args.end,
      );

      return AttendanceBreakdown(
        weekdays: countWeekdays(args.start, args.end),
        officeDays: officeWeekdays,
        weekendOfficeDays: officeTotal - officeWeekdays,
        specialDayCounts: specialDayCounts,
      );
    });

/// One week's return-to-office figure for the Insights trend chart.
typedef TrendPoint = ({DateTime weekStart, double? percentage});

/// Return-to-office percentage for each of the last 8 ISO weeks (Mon–Sun),
/// oldest first, for the given office. Uses the same weekday-based maths as
/// [breakdownProvider] so the trend agrees with the headline percentage.
final weeklyTrendProvider = FutureProvider.autoDispose
    .family<List<TrendPoint>, int>((ref, officeId) async {
      final db = DatabaseService.instance;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      // Monday of the current week.
      final thisMonday = today.subtract(Duration(days: today.weekday - 1));
      const weeks = 8;

      final points = <TrendPoint>[];
      for (var i = weeks - 1; i >= 0; i--) {
        final start = thisMonday.subtract(Duration(days: 7 * i));
        final end = start.add(const Duration(days: 6));
        final office = await db.getAttendanceCount(
          officeId,
          from: start,
          to: end,
          weekdaysOnly: true,
        );
        final special = await db.getSpecialDayCountsByType(start, end);
        final excluded = excludedFromAttendanceDenominator.fold<int>(
          0,
          (sum, type) => sum + (special[type] ?? 0),
        );
        final eligible = countWeekdays(start, end) - excluded;
        final pct = eligible <= 0
            ? null
            : (office / eligible * 100).clamp(0.0, 100.0);
        points.add((weekStart: start, percentage: pct));
      }
      return points;
    });

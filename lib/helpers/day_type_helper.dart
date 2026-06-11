import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../models/special_day.dart';

extension DayTypeX on DayType {
  String get label => switch (this) {
    DayType.holiday => 'Public Holiday',
    DayType.sickLeave => 'Sick Leave',
    DayType.annualLeave => 'Annual Leave',
    DayType.carersLeave => "Carer's Leave",
    DayType.workFromHome => 'Work from Home',
    DayType.miscLeave => 'Misc Leave',
  };

  String get description => switch (this) {
    DayType.holiday => 'A non-working public holiday',
    DayType.sickLeave => 'Off sick on this day',
    DayType.annualLeave => 'On annual (holiday) leave',
    DayType.carersLeave => 'Caring for someone on this day',
    DayType.workFromHome => 'Worked, but not from the office',
    DayType.miscLeave => 'Other leave (treated like sick/annual leave)',
  };

  IconData get icon => switch (this) {
    DayType.holiday => Icons.beach_access_outlined,
    DayType.sickLeave => Icons.sick_outlined,
    DayType.annualLeave => Icons.luggage_outlined,
    DayType.carersLeave => Icons.volunteer_activism_outlined,
    DayType.workFromHome => Icons.home_work_outlined,
    DayType.miscLeave => Icons.cancel_outlined,
  };

  Color get color => switch (this) {
    DayType.holiday => AppColors.holiday,
    DayType.sickLeave => AppColors.sickLeave,
    DayType.annualLeave => AppColors.annualLeave,
    DayType.carersLeave => AppColors.carersLeave,
    DayType.workFromHome => AppColors.workFromHome,
    DayType.miscLeave => AppColors.miscLeave,
  };

  DayStatus get dayStatus => switch (this) {
    DayType.holiday => DayStatus.holiday,
    DayType.sickLeave => DayStatus.sickLeave,
    DayType.annualLeave => DayStatus.annualLeave,
    DayType.carersLeave => DayStatus.carersLeave,
    DayType.workFromHome => DayStatus.workFromHome,
    DayType.miscLeave => DayStatus.miscLeave,
  };

  /// Theme-aware colour (brighter shades in dark mode). Prefer this over
  /// [color] anywhere a BuildContext is available.
  Color colorIn(BuildContext context) {
    final c = DayTypeColors.of(context);
    return switch (this) {
      DayType.holiday => c.holiday,
      DayType.sickLeave => c.sickLeave,
      DayType.annualLeave => c.annualLeave,
      DayType.carersLeave => c.carersLeave,
      DayType.workFromHome => c.workFromHome,
      DayType.miscLeave => c.miscLeave,
    };
  }
}

extension DayStatusX on DayStatus {
  String get label => switch (this) {
    DayStatus.attended => 'Attended',
    DayStatus.holiday => 'Public Holiday',
    DayStatus.sickLeave => 'Sick Leave',
    DayStatus.annualLeave => 'Annual Leave',
    DayStatus.carersLeave => "Carer's Leave",
    DayStatus.workFromHome => 'Work from Home',
    DayStatus.miscLeave => 'Misc Leave',
  };

  String get description => switch (this) {
    DayStatus.attended => 'You were at the office',
    DayStatus.holiday => 'A non-working public holiday',
    DayStatus.sickLeave => 'Off sick on this day',
    DayStatus.annualLeave => 'On annual (holiday) leave',
    DayStatus.carersLeave => 'Caring for someone on this day',
    DayStatus.workFromHome => 'Worked, but not from the office',
    DayStatus.miscLeave => 'Other leave (treated like sick/annual leave)',
  };

  IconData get icon => switch (this) {
    DayStatus.attended => Icons.check_circle_outline,
    DayStatus.holiday => Icons.beach_access_outlined,
    DayStatus.sickLeave => Icons.sick_outlined,
    DayStatus.annualLeave => Icons.luggage_outlined,
    DayStatus.carersLeave => Icons.volunteer_activism_outlined,
    DayStatus.workFromHome => Icons.home_work_outlined,
    DayStatus.miscLeave => Icons.cancel_outlined,
  };

  Color get color => switch (this) {
    DayStatus.attended => AppColors.attendance,
    DayStatus.holiday => AppColors.holiday,
    DayStatus.sickLeave => AppColors.sickLeave,
    DayStatus.annualLeave => AppColors.annualLeave,
    DayStatus.carersLeave => AppColors.carersLeave,
    DayStatus.workFromHome => AppColors.workFromHome,
    DayStatus.miscLeave => AppColors.miscLeave,
  };

  DayType get dayType => switch (this) {
    DayStatus.holiday => DayType.holiday,
    DayStatus.sickLeave => DayType.sickLeave,
    DayStatus.annualLeave => DayType.annualLeave,
    DayStatus.carersLeave => DayType.carersLeave,
    DayStatus.workFromHome => DayType.workFromHome,
    DayStatus.miscLeave => DayType.miscLeave,
    DayStatus.attended => throw UnimplementedError('No DayType for attended'),
  };

  /// Theme-aware colour (brighter shades in dark mode). Prefer this over
  /// [color] anywhere a BuildContext is available.
  Color colorIn(BuildContext context) {
    final c = DayTypeColors.of(context);
    return switch (this) {
      DayStatus.attended => c.attendance,
      DayStatus.holiday => c.holiday,
      DayStatus.sickLeave => c.sickLeave,
      DayStatus.annualLeave => c.annualLeave,
      DayStatus.carersLeave => c.carersLeave,
      DayStatus.workFromHome => c.workFromHome,
      DayStatus.miscLeave => c.miscLeave,
    };
  }
}

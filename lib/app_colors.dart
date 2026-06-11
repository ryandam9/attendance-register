import 'package:flutter/material.dart';

/// Semantic colour tokens shared across the whole app.
///
/// Using slightly deeper shades than bare Material primaries to ensure
/// readable contrast on white/light surfaces and in calendar dots.
abstract final class AppColors {
  static const Color attendance  = Color(0xFF2E7D32); // green[800]
  static const Color holiday     = Color(0xFF1565C0); // blue[800]
  static const Color sickLeave   = Color(0xFFE65100); // deepOrange[900]
  static const Color annualLeave = Color(0xFF6A1B9A); // purple[800]
  static const Color carersLeave = Color(0xFF00838F); // cyan[800]
  static const Color workFromHome = Color(0xFFAD1457); // pink[800]
  static const Color miscLeave = Color(0xFF616161); // grey[700]
}

/// Day-type colours as a theme extension, so dark mode can use brighter
/// shades (the light palette above is tuned for white surfaces and loses
/// pop on dark ones). Look up via `Theme.of(context).extension<DayTypeColors>()`
/// or the `colorIn(context)` helpers in day_type_helper.dart.
@immutable
class DayTypeColors extends ThemeExtension<DayTypeColors> {
  final Color attendance;
  final Color holiday;
  final Color sickLeave;
  final Color annualLeave;
  final Color carersLeave;
  final Color workFromHome;
  final Color miscLeave;

  const DayTypeColors({
    required this.attendance,
    required this.holiday,
    required this.sickLeave,
    required this.annualLeave,
    required this.carersLeave,
    required this.workFromHome,
    required this.miscLeave,
  });

  static const light = DayTypeColors(
    attendance: AppColors.attendance,
    holiday: AppColors.holiday,
    sickLeave: AppColors.sickLeave,
    annualLeave: AppColors.annualLeave,
    carersLeave: AppColors.carersLeave,
    workFromHome: AppColors.workFromHome,
    miscLeave: AppColors.miscLeave,
  );

  static const dark = DayTypeColors(
    attendance: Color(0xFF81C784), // green[300]
    holiday: Color(0xFF64B5F6), // blue[300]
    sickLeave: Color(0xFFFF8A65), // deepOrange[300]
    annualLeave: Color(0xFFBA68C8), // purple[300]
    carersLeave: Color(0xFF4DD0E1), // cyan[300]
    workFromHome: Color(0xFFF06292), // pink[300]
    miscLeave: Color(0xFFBDBDBD), // grey[400]
  );

  @override
  DayTypeColors copyWith({
    Color? attendance,
    Color? holiday,
    Color? sickLeave,
    Color? annualLeave,
    Color? carersLeave,
    Color? workFromHome,
    Color? miscLeave,
  }) =>
      DayTypeColors(
        attendance: attendance ?? this.attendance,
        holiday: holiday ?? this.holiday,
        sickLeave: sickLeave ?? this.sickLeave,
        annualLeave: annualLeave ?? this.annualLeave,
        carersLeave: carersLeave ?? this.carersLeave,
        workFromHome: workFromHome ?? this.workFromHome,
        miscLeave: miscLeave ?? this.miscLeave,
      );

  @override
  DayTypeColors lerp(DayTypeColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return DayTypeColors(
      attendance: l(attendance, other.attendance),
      holiday: l(holiday, other.holiday),
      sickLeave: l(sickLeave, other.sickLeave),
      annualLeave: l(annualLeave, other.annualLeave),
      carersLeave: l(carersLeave, other.carersLeave),
      workFromHome: l(workFromHome, other.workFromHome),
      miscLeave: l(miscLeave, other.miscLeave),
    );
  }

  static DayTypeColors of(BuildContext context) =>
      Theme.of(context).extension<DayTypeColors>() ?? light;
}

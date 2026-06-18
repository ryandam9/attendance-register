import 'package:flutter/material.dart';

/// Semantic colour tokens shared across the whole app.
///
/// These are the exact Feathers "Rainbow Bee-eater" status colours — kept in
/// one place so calendar dots, chips, the day-entry selector and the Insights
/// legend all stay in sync. Each status also carries an icon + label elsewhere
/// (see day_type_helper.dart) so meaning never relies on colour alone.
abstract final class AppColors {
  static const Color attendance   = Color(0xFF6D8600); // olive green
  static const Color holiday      = Color(0xFF007CBF); // bright blue
  static const Color sickLeave    = Color(0xFFF5A200); // orange
  static const Color annualLeave  = Color(0xFF7090C9); // soft blue-purple
  static const Color carersLeave  = Color(0xFF3EBCB6); // teal
  static const Color workFromHome = Color(0xFFBD338F); // magenta
  static const Color miscLeave    = Color(0xFF727B98); // grey-slate
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

  // Brighter shades of the Feathers status colours, lifted for legibility on
  // the dark navy surfaces (#061522 / #0B2236) without becoming neon.
  static const dark = DayTypeColors(
    attendance: Color(0xFFAFD135), // lifted olive
    holiday: Color(0xFF45B6E8), // lifted bright blue
    sickLeave: Color(0xFFFFC04D), // lifted orange
    annualLeave: Color(0xFF9DB4E0), // lifted blue-purple
    carersLeave: Color(0xFF5FD6CF), // lifted teal
    workFromHome: Color(0xFFE673BD), // lifted magenta
    miscLeave: Color(0xFF9AA3BC), // lifted grey-slate
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

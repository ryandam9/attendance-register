import 'package:flutter/material.dart';

/// Semantic colour tokens shared across the whole app.
///
/// Botanical status colours shared by calendars, chips and charts. Each status
/// also has an icon and label, so meaning never depends on colour alone.
abstract final class AppColors {
  static const Color attendance = Color(0xFF486338); // olive green
  static const Color holiday = Color(0xFF37627B); // dusty blue
  static const Color sickLeave = Color(0xFF815625); // warm ochre
  static const Color annualLeave = Color(0xFF5E5781); // soft blue-purple
  static const Color carersLeave = Color(0xFF2B655D); // teal
  static const Color workFromHome = Color(0xFF7C5363); // muted rose
  static const Color miscLeave = Color(0xFF58616E); // grey-slate
}

/// Status colours adapted to light paper and dark charcoal surfaces.
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

  // Soft, distinct accents with sufficient contrast on charcoal surfaces.
  static const dark = DayTypeColors(
    attendance: Color(0xFFACC69B), // soft sage
    holiday: Color(0xFF9EBFD2), // dusty sky
    sickLeave: Color(0xFFDCB783), // lifted orange
    annualLeave: Color(0xFFBAB2D6), // lifted blue-purple
    carersLeave: Color(0xFF9BC9BD), // lifted teal
    workFromHome: Color(0xFFD2A6B6), // soft rose
    miscLeave: Color(0xFFB5BDC9), // lifted grey-slate
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
  }) => DayTypeColors(
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

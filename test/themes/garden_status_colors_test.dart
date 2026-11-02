import 'package:attendance_register/app_colors.dart';
import 'package:attendance_register/themes/garden_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Status text retains AA contrast on garden surfaces and tinted chips',
    () {
      for (final brightness in Brightness.values) {
        final theme = gardenTheme(brightness);
        final colors = theme.extension<DayTypeColors>()!;
        for (final color in [
          colors.attendance,
          colors.holiday,
          colors.sickLeave,
          colors.annualLeave,
          colors.carersLeave,
          colors.workFromHome,
          colors.miscLeave,
        ]) {
          for (final surface in [
            theme.colorScheme.surface,
            theme.colorScheme.surfaceContainerLow,
          ]) {
            for (final background in [
              surface,
              Color.alphaBlend(color.withValues(alpha: 0.14), surface),
            ]) {
              final a = color.computeLuminance();
              final b = background.computeLuminance();
              final contrast =
                  (a > b ? a + 0.05 : b + 0.05) / (a > b ? b + 0.05 : a + 0.05);
              expect(
                contrast,
                greaterThanOrEqualTo(4.5),
                reason: '$brightness $color on $background',
              );
            }
          }
        }
      }
    },
  );
}

import 'package:attendance_register/themes/bird_themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrastRatio(Color a, Color b) {
  final lighter = a.computeLuminance() > b.computeLuminance() ? a : b;
  final darker = identical(lighter, a) ? b : a;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}

void main() {
  test('bird theme action colours meet WCAG AA contrast', () {
    for (final bird in birdThemes) {
      for (final brightness in Brightness.values) {
        final scheme = bird.themeData(brightness).colorScheme;
        expect(
          _contrastRatio(scheme.primary, scheme.onPrimary),
          greaterThanOrEqualTo(4.5),
          reason: '${bird.name} $brightness primary contrast',
        );
        expect(
          _contrastRatio(scheme.secondary, scheme.onSecondary),
          greaterThanOrEqualTo(4.5),
          reason: '${bird.name} $brightness secondary contrast',
        );
      }
    }
  });
}

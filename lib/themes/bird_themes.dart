import 'package:flutter/material.dart';

import '../app_colors.dart';

/// Theme id that selects the device's Material You palette instead of a bird
/// palette (Android 12+; elsewhere it falls back to the default bird theme).
const dynamicThemeId = 'dynamic';

/// Builds the app's ThemeData from any [ColorScheme] — bird palettes and
/// Material You dynamic schemes share the same component styling, type scale
/// and day-type colour extension.
ThemeData buildAppTheme(ColorScheme scheme) {
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  final dark = scheme.brightness == Brightness.dark;
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 2,
    ),
    // Predictive back on Android 14+ (the system back gesture previews the
    // destination); standard Cupertino slide on iOS.
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
    extensions: [dark ? DayTypeColors.dark : DayTypeColors.light],
    // The big numbers (stat cards, Explain hero) are the app's identity:
    // heavier weight, tighter tracking, and tabular figures so animated
    // count-ups don't jiggle as digits change.
    textTheme: base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
  );
}

class BirdTheme {
  final String id;
  final String name;
  final Color primary;
  final Color secondary;
  final Color tertiary;

  const BirdTheme({
    required this.id,
    required this.name,
    required this.primary,
    required this.secondary,
    required this.tertiary,
  });

  /// Black or white, whichever contrasts with [background]. Overriding a
  /// scheme colour without its "on" partner risks the seed-derived on-colour
  /// (e.g. white) landing on a light bird colour like the Plains-wanderer's
  /// beige — unreadable buttons and badges.
  static Color _onColor(Color background) =>
      background.computeLuminance() > 0.5 ? Colors.black : Colors.white;

  ThemeData themeData(Brightness brightness) => buildAppTheme(
    ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      onPrimary: _onColor(primary),
      secondary: secondary,
      onSecondary: _onColor(secondary),
      tertiary: tertiary,
      onTertiary: _onColor(tertiary),
      brightness: brightness,
    ),
  );
}

/// Australian bird colour palettes by Feathers.
/// Each maps 3 key colours to primary / secondary / tertiary roles.
const birdThemes = [
  BirdTheme(
    id: 'default',
    name: 'Default',
    primary: Color(0xFF1A73E8),
    secondary: Color(0xFF5F6368),
    tertiary: Color(0xFF34A853),
  ),
  BirdTheme(
    id: 'spotted_pardalote',
    name: 'Spotted Pardalote',
    primary: Color(0xFFcb0300),
    secondary: Color(0xFFfeca00),
    tertiary: Color(0xFFd36328),
  ),
  BirdTheme(
    id: 'plains_wanderer',
    name: 'Plains-wanderer',
    primary: Color(0xFFEDD8C5),
    secondary: Color(0xFFe7aa01),
    tertiary: Color(0xFFd09a5e),
  ),
  BirdTheme(
    id: 'bee_eater',
    name: 'Rainbow Bee-eater',
    primary: Color(0xFF00346E),
    secondary: Color(0xFFEDD03E),
    tertiary: Color(0xFF6D8600),
  ),
  BirdTheme(
    id: 'rose_crowned_fruit_dove',
    name: 'Rose-crowned Fruit Dove',
    primary: Color(0xFFBD338F),
    secondary: Color(0xFFEB8252),
    tertiary: Color(0xFF8FA33F),
  ),
  BirdTheme(
    id: 'eastern_rosella',
    name: 'Eastern Rosella',
    primary: Color(0xFF2F533C),
    secondary: Color(0xFFf4c623),
    tertiary: Color(0xFF2f7ab9),
  ),
  BirdTheme(
    id: 'oriole',
    name: 'Olivaceous Oriole',
    primary: Color(0xFFb8a53f),
    tertiary: Color(0xFFbb5645),
    secondary: Color(0xFFa29eb8),
  ),
  BirdTheme(
    id: 'princess_parrot',
    name: 'Princess Parrot',
    primary: Color(0xFF7090c9),
    secondary: Color(0xFF6eb245),
    tertiary: Color(0xFFcf2236),
  ),
  BirdTheme(
    id: 'superb_fairy_wren',
    name: 'Superb Fairy-wren',
    primary: Color(0xFFB03F05),
    secondary: Color(0xFFAA7853),
    tertiary: Color(0xFF4F3321),
  ),
  BirdTheme(
    id: 'cassowary',
    name: 'Cassowary',
    primary: Color(0xFF0169C4),
    secondary: Color(0xFFBDA14D),
    tertiary: Color(0xFFD5114E),
  ),
  BirdTheme(
    id: 'yellow_robin',
    name: 'Eastern Yellow Robin',
    primary: Color(0xFF979EB9),
    secondary: Color(0xFFE19E00),
    tertiary: Color(0xFF85773A),
  ),
  BirdTheme(
    id: 'galah',
    name: 'Galah',
    primary: Color(0xFFD05478),
    secondary: Color(0xFFE9A7BB),
    tertiary: Color(0xFF4C5766),
  ),
  BirdTheme(
    id: 'blue_winged_kookaburra',
    name: 'Blue-winged Kookaburra',
    primary: Color(0xFFAD8D9F),
    secondary: Color(0xFF0B7595),
    tertiary: Color(0xFFB5EFFB),
  ),
];

BirdTheme birdThemeById(String id) =>
    birdThemes.firstWhere((t) => t.id == id, orElse: () => birdThemes.first);

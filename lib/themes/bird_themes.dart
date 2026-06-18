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
    // Feathers direction: a solid coloured app bar (deep navy for the default
    // Rainbow Bee-eater) with white text in light mode. In dark mode a tinted
    // surface reads far better than M3's light-toned primary, so use that.
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? scheme.surface : scheme.primary,
      foregroundColor: dark ? scheme.onSurface : scheme.onPrimary,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: dark ? 2 : 0,
    ),
    // Primary buttons use the palette's secondary (bright blue #007CBF for the
    // default theme) per the Feathers spec, keeping the deep navy reserved for
    // the app bar and selected states.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.secondary,
        foregroundColor: scheme.onSecondary,
      ),
    ),
    // No pageTransitionsTheme override: the framework defaults already map
    // Android to PredictiveBackPageTransitionsBuilder (the 14+ back-gesture
    // preview, enabled via enableOnBackInvokedCallback in the manifest) and
    // iOS to the Cupertino slide.
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
  final String description;
  final Color primary;
  final Color secondary;
  final Color tertiary;

  const BirdTheme({
    required this.id,
    required this.name,
    required this.description,
    required this.primary,
    required this.secondary,
    required this.tertiary,
  });

  /// The palette's key colours, in role order, for swatch rows in the
  /// Appearance screen.
  List<Color> get swatches => [primary, secondary, tertiary];

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
///
/// Rainbow Bee-eater is first so it is the app's default theme; its three roles
/// follow the Feathers spec exactly — deep navy app bar (#00346E), bright-blue
/// buttons (#007CBF), cyan accents (#06ABDF).
const birdThemes = [
  BirdTheme(
    id: 'bee_eater',
    name: 'Rainbow Bee-eater',
    description: 'Bright, focused, professional',
    primary: Color(0xFF00346E),
    secondary: Color(0xFF007CBF),
    tertiary: Color(0xFF06ABDF),
  ),
  BirdTheme(
    id: 'spotted_pardalote',
    name: 'Spotted Pardalote',
    description: 'Bold, alert, high contrast',
    primary: Color(0xFFcb0300),
    secondary: Color(0xFFfeca00),
    tertiary: Color(0xFFd36328),
  ),
  BirdTheme(
    id: 'plains_wanderer',
    name: 'Plains-wanderer',
    description: 'Calm, warm, earthy',
    primary: Color(0xFFEDD8C5),
    secondary: Color(0xFFe7aa01),
    tertiary: Color(0xFFd09a5e),
  ),
  BirdTheme(
    id: 'rose_crowned_fruit_dove',
    name: 'Rose-crowned Fruit Dove',
    description: 'Friendly, soft, colourful',
    primary: Color(0xFFBD338F),
    secondary: Color(0xFFEB8252),
    tertiary: Color(0xFF8FA33F),
  ),
  BirdTheme(
    id: 'eastern_rosella',
    name: 'Eastern Rosella',
    description: 'Natural, bright, balanced',
    primary: Color(0xFF2F533C),
    secondary: Color(0xFFf4c623),
    tertiary: Color(0xFF2f7ab9),
  ),
  BirdTheme(
    id: 'oriole',
    name: 'Olivaceous Oriole',
    description: 'Mellow, golden, understated',
    primary: Color(0xFFb8a53f),
    tertiary: Color(0xFFbb5645),
    secondary: Color(0xFFa29eb8),
  ),
  BirdTheme(
    id: 'princess_parrot',
    name: 'Princess Parrot',
    description: 'Fresh, lively, optimistic',
    primary: Color(0xFF7090c9),
    secondary: Color(0xFF6eb245),
    tertiary: Color(0xFFcf2236),
  ),
  BirdTheme(
    id: 'superb_fairy_wren',
    name: 'Superb Fairy-wren',
    description: 'Rich, grounded, autumnal',
    primary: Color(0xFFB03F05),
    secondary: Color(0xFFAA7853),
    tertiary: Color(0xFF4F3321),
  ),
  BirdTheme(
    id: 'cassowary',
    name: 'Cassowary',
    description: 'Bold, dark, dramatic',
    primary: Color(0xFF0169C4),
    secondary: Color(0xFFBDA14D),
    tertiary: Color(0xFFD5114E),
  ),
  BirdTheme(
    id: 'yellow_robin',
    name: 'Eastern Yellow Robin',
    description: 'Soft, sunny, gentle',
    primary: Color(0xFF979EB9),
    secondary: Color(0xFFE19E00),
    tertiary: Color(0xFF85773A),
  ),
  BirdTheme(
    id: 'galah',
    name: 'Galah',
    description: 'Soft, relaxed, playful',
    primary: Color(0xFFD05478),
    secondary: Color(0xFFE9A7BB),
    tertiary: Color(0xFF4C5766),
  ),
  BirdTheme(
    id: 'blue_winged_kookaburra',
    name: 'Blue-winged Kookaburra',
    description: 'Cool, vivid, striking',
    primary: Color(0xFFAD8D9F),
    secondary: Color(0xFF0B7595),
    tertiary: Color(0xFFB5EFFB),
  ),
];

BirdTheme birdThemeById(String id) =>
    birdThemes.firstWhere((t) => t.id == id, orElse: () => birdThemes.first);

import 'package:flutter/material.dart';
import '../app_colors.dart';

/// A single botanical identity, independent of previously saved bird palettes.
ThemeData gardenTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final seeded = ColorScheme.fromSeed(
    seedColor: const Color(0xFF315741),
    brightness: brightness,
    primary: dark ? const Color(0xFFB0CFA0) : const Color(0xFF315741),
    onPrimary: dark ? const Color(0xFF19351F) : Colors.white,
    surface: dark ? const Color(0xFF17271F) : const Color(0xFFF1F3EB),
    onSurface: dark ? const Color(0xFFE1E9D7) : const Color(0xFF294936),
    surfaceContainerLow: dark
        ? const Color(0xFF22372A)
        : const Color(0xFFFAFBF5),
    outlineVariant: dark ? const Color(0xFF3E5141) : const Color(0xFFDCE2D4),
  );
  // Explicit neutral roles keep the botanical seed from tinting every surface,
  // input, sheet, chart track, and secondary control green in dark mode.
  final scheme = dark
      ? seeded.copyWith(
          primary: const Color(0xFFA8C49A),
          onPrimary: const Color(0xFF20341C),
          primaryContainer: const Color(0xFF30392D),
          onPrimaryContainer: const Color(0xFFDCE8D5),
          secondary: const Color(0xFFC5C5C5),
          onSecondary: const Color(0xFF262626),
          secondaryContainer: const Color(0xFF343434),
          onSecondaryContainer: const Color(0xFFE5E5E5),
          tertiary: const Color(0xFFD4B59E),
          onTertiary: const Color(0xFF38291E),
          tertiaryContainer: const Color(0xFF43372E),
          onTertiaryContainer: const Color(0xFFF0DCCC),
          surface: const Color(0xFF171717),
          surfaceDim: const Color(0xFF171717),
          surfaceBright: const Color(0xFF383838),
          surfaceContainerLowest: const Color(0xFF121212),
          surfaceContainerLow: const Color(0xFF202020),
          surfaceContainer: const Color(0xFF252525),
          surfaceContainerHigh: const Color(0xFF2C2C2C),
          surfaceContainerHighest: const Color(0xFF343434),
          onSurface: const Color(0xFFE7E7E7),
          onSurfaceVariant: const Color(0xFFBEBEBE),
          outline: const Color(0xFF898989),
          outlineVariant: const Color(0xFF424242),
          inverseSurface: const Color(0xFFE7E7E7),
          onInverseSurface: const Color(0xFF252525),
          surfaceTint: Colors.transparent,
        )
      // The seed's light container is a bright mint; the garden design uses a
      // soft sage for tags, selected tiles, the nav indicator and the FAB.
      : seeded.copyWith(
          primaryContainer: const Color(0xFFE1E9D9),
          onPrimaryContainer: const Color(0xFF294936),
        );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'DM Sans',
  );
  TextStyle? heading(TextStyle? style) => style?.copyWith(
    fontFamily: 'DM Sans',
    fontWeight: FontWeight.w500,
    letterSpacing: -0.4,
  );
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: base.textTheme.copyWith(
      headlineLarge: heading(base.textTheme.headlineLarge),
      headlineMedium: heading(base.textTheme.headlineMedium),
      headlineSmall: heading(base.textTheme.headlineSmall),
      // Large metrics remain in the interface font with stable digit widths.
      displaySmall: base.textTheme.displaySmall?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      surfaceTintColor: Colors.transparent,
      color: scheme.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: const StadiumBorder(),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      elevation: 0,
    ),
    extensions: [dark ? DayTypeColors.dark : DayTypeColors.light],
  );
}

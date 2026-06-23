import 'dart:io' show Platform;

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_geofence/native_geofence.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'providers/settings_provider.dart';
import 'screens/main_shell.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'themes/bird_themes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop Linux/Windows have no native sqflite plugin — back the database
  // with the FFI implementation (bundled sqlite3). Android, iOS and macOS use
  // the native sqflite plugin and need no setup here.
  if (!kIsWeb && (Platform.isLinux || Platform.isWindows)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await DatabaseService.instance.database;
  await NotificationService.instance.initialize();
  // Geofencing powers auto check-in but must never block the app from
  // starting — if the plugin fails to initialise (missing Play Services,
  // unsupported platform), the user can still view and record days manually.
  try {
    await NativeGeofenceManager.instance.initialize();
  } catch (e) {
    debugPrint('Geofencing unavailable: $e');
  }

  runApp(const ProviderScope(child: AttendanceApp()));
}

class AttendanceApp extends ConsumerWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    MaterialApp buildApp(ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
      ThemeData light;
      ThemeData dark;
      if (settings.themeId == dynamicThemeId &&
          lightDynamic != null &&
          darkDynamic != null) {
        // Material You: the device's wallpaper-derived palette (Android 12+).
        light = buildAppTheme(lightDynamic.harmonized());
        dark = buildAppTheme(darkDynamic.harmonized());
      } else {
        final bird = settings.theme;
        light = bird.themeData(Brightness.light);
        dark = bird.themeData(Brightness.dark);
      }
      return MaterialApp(
        title: 'Office Attendance',
        debugShowCheckedModeBanner: false,
        theme: light,
        darkTheme: dark,
        themeMode: settings.themeMode,
        home: const MainShell(),
      );
    }

    // dynamic_color's native accent query has crashed the app on some Linux/
    // Windows desktop setups, and Material You only applies on Android — so skip
    // the plugin there and use the built-in app themes.
    if (!kIsWeb && (Platform.isLinux || Platform.isWindows)) {
      return buildApp(null, null);
    }

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) =>
          buildApp(lightDynamic, darkDynamic),
    );
  }
}

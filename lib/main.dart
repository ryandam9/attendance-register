import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_geofence/native_geofence.dart';

import 'providers/settings_provider.dart';
import 'screens/main_shell.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'themes/bird_themes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
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
      },
    );
  }
}

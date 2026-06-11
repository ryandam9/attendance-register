import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_geofence/native_geofence.dart';

import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';

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
    final theme = ref.watch(settingsProvider).theme;
    return MaterialApp(
      title: 'Office Attendance',
      debugShowCheckedModeBanner: false,
      theme: theme.themeData(Brightness.light),
      darkTheme: theme.themeData(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart'
    show kIsWeb, LicenseRegistry, LicenseEntryWithLineBreaks;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:native_geofence/native_geofence.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'providers/settings_provider.dart';
import 'screens/main_shell.dart';
import 'services/database_service.dart';
import 'services/location_service.dart';
import 'services/notification_service.dart';
import 'themes/garden_theme.dart';

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
  // Geofencing powers auto check-in but is Android/iOS only and must never
  // block the app from starting. Skip it entirely on unsupported platforms;
  // elsewhere a failure (e.g. missing Play Services) is non-fatal.
  if (isGeofencingSupported) {
    try {
      await NativeGeofenceManager.instance.initialize();
    } catch (e) {
      debugPrint('Geofencing unavailable: $e');
    }
  }

  LicenseRegistry.addLicense(() async* {
    final licence = await rootBundle.loadString('assets/fonts/DMSans-OFL.txt');
    yield LicenseEntryWithLineBreaks(['DM Sans'], licence);
  });

  runApp(const ProviderScope(child: AttendanceApp()));
}

class AttendanceApp extends ConsumerWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'Office Attendance',
      debugShowCheckedModeBanner: false,
      theme: gardenTheme(Brightness.light),
      darkTheme: gardenTheme(Brightness.dark),
      themeMode: settings.themeMode,
      home: const MainShell(),
    );
  }
}

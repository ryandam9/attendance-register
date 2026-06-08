import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';
import 'services/database_service.dart';
import 'services/location_service.dart';
import 'services/notification_service.dart';

const _backgroundTaskName = 'attendanceLocationCheck';

/// Top-level callback required by WorkManager — must not be a class method.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == _backgroundTaskName) {
      await LocationService.performBackgroundCheck();
    }
    return true;
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await DatabaseService.instance.database;
  await NotificationService.instance.initialize();

  await Workmanager().initialize(callbackDispatcher);

  // Android enforces a minimum of 15 minutes for periodic tasks.
  await Workmanager().registerPeriodicTask(
    _backgroundTaskName,
    _backgroundTaskName,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.notRequired),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );

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

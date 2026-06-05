import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
  }

  Future<void> showAttendanceRecorded(String officeName) async {
    await _plugin.show(
      0,
      'Attendance Recorded ✓',
      'Your attendance at $officeName has been registered for today.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'attendance_channel',
          'Attendance',
          channelDescription: 'Notifies when office attendance is recorded',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}

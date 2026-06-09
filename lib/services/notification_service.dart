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
      settings: const InitializationSettings(android: android, iOS: ios),
    );
  }

  Future<void> showAttendanceRecorded(String officeName, String date) async {
    await _plugin.show(
      id: 0,
      title: 'Attendance Recorded ✓',
      body: 'Hey $officeName, your attendance at office has been recorded for $date.',
      notificationDetails: const NotificationDetails(
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

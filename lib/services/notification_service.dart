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

  /// [id] should be unique per office (e.g. the office row id) so same-day
  /// check-ins at different offices don't overwrite each other's notification.
  Future<void> showAttendanceRecorded(String name, String date, {int id = 0}) async {
    await _plugin.show(
      id: id,
      title: 'Attendance Recorded ✓',
      body: 'Hey $name, your attendance at office has been recorded for $date.',
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

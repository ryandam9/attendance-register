import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

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
  ///
  /// [name] is the user's name from settings; it falls back to "there" at the
  /// call site when no name has been saved.
  Future<void> showAttendanceRecorded(
    String name,
    DateTime timestamp, {
    int id = 0,
  }) async {
    final date = DateFormat('d MMM yyyy').format(timestamp);
    final time = DateFormat('h:mm a').format(timestamp);

    // Original wording, kept as-is — emoji add the festive touch OS
    // notifications can't animate.
    const title = 'Attendance Recorded 🎉';
    final body =
        'Hey $name, your attendance at office has been recorded '
        'for $date at $time. 🎈🚀';

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'attendance_channel',
          'Attendance',
          channelDescription: 'Notifies when office attendance is recorded',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          // Expandable body so the full message + emoji show.
          styleInformation: BigTextStyleInformation(body, contentTitle: title),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}

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

  /// Celebratory titles. OS notifications can't animate, so emoji carry the
  /// "balloons popping up" feeling the plain text was missing.
  static const _titles = [
    '🎉 Attendance Recorded!',
    '✅ You\'re Checked In!',
    '🏢 Welcome to the Office!',
    '🌟 Another Day at the Office!',
    '🎈 Check-In Complete!',
  ];

  /// Body builders. Each takes the resolved [name], [date] and [time] so the
  /// preposition reads naturally — "for <date> at <time>".
  static final List<String Function(String, String, String)> _bodies = [
    (n, d, t) =>
        'Hey $n! 🎊 Your office attendance is on the board for $d at $t. '
        'Have a great one! 🚀',
    (n, d, t) => 'Nice work, $n! 🏢✨ We logged you in for $d at $t.',
    (n, d, t) => 'Boom! 💥 $n, your attendance for $d at $t is locked in. 🔒',
    (n, d, t) => 'Got you, $n! 📌 Office check-in recorded for $d at $t. 🎈',
    (n, d, t) => 'High five, $n! 🙌 You\'re marked present for $d at $t. ✅',
  ];

  /// [id] should be unique per office (e.g. the office row id) so same-day
  /// check-ins at different offices don't overwrite each other's notification.
  Future<void> showAttendanceRecorded(
    String name,
    DateTime timestamp, {
    int id = 0,
  }) async {
    final date = DateFormat('d MMM yyyy').format(timestamp);
    final time = DateFormat('h:mm a').format(timestamp);

    // Vary the copy by day so a re-fire on the same day stays consistent while
    // day-to-day check-ins feel fresh.
    final pick = timestamp.difference(DateTime(timestamp.year)).inDays;
    final title = _titles[pick % _titles.length];
    final body = _bodies[pick % _bodies.length](name, date, time);

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
          // Expandable body so the full celebratory message + emoji show.
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
          ),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}

import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

class AttendanceNotificationContent {
  const AttendanceNotificationContent({
    required this.title,
    required this.body,
    required this.expandedBody,
    required this.date,
    required this.shortDate,
    required this.office,
  });

  final String title;
  final String body;
  final String expandedBody;
  final String date;

  /// Date without the year, for the iOS subtitle: "Mon, 16 Nov".
  final String shortDate;
  final String office;
}

/// Builds the short, glanceable copy used by the platform notification.
///
/// Kept outside [NotificationService] so the wording can be tested without
/// initialising a native notifications plugin.
AttendanceNotificationContent buildAttendanceNotificationContent({
  required String name,
  required String officeName,
  required DateTime timestamp,
}) {
  final displayName = name.trim();
  final displayOffice = officeName.trim().isEmpty
      ? 'Office'
      : officeName.trim();
  final date = DateFormat('EEE, d MMM yyyy').format(timestamp);
  final time = DateFormat('h:mm a').format(timestamp);
  final title = displayName.isEmpty || displayName.toLowerCase() == 'there'
      ? 'You’re checked in'
      : 'Checked in, $displayName';

  return AttendanceNotificationContent(
    title: title,
    body: '$displayOffice · $time',
    expandedBody:
        'Your attendance at $displayOffice was recorded.\n$date · $time',
    date: date,
    shortDate: DateFormat('EEE, d MMM').format(timestamp),
    office: displayOffice,
  );
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    // Shared by iOS and macOS — both use the Darwin (Apple) notification stack.
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: false,
    );
    // Required when running on Linux desktop.
    const linux = LinuxInitializationSettings(defaultActionName: 'Open');
    // Required when running on Windows desktop.
    const windows = WindowsInitializationSettings(
      appName: 'Attendance Register',
      appUserModelId: 'com.example.attendanceRegister',
      // Stable GUID identifying this app to the Windows notification system.
      guid: '6e3a8c2f-9b1d-4f2a-8a3e-2f7c9d4b1a55',
    );
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
        linux: linux,
        windows: windows,
      ),
    );
  }

  /// [id] should be unique per office (e.g. the office row id) so same-day
  /// check-ins at different offices don't overwrite each other's notification.
  ///
  /// [name] is the user's name from settings; it falls back to "there" at the
  /// call site when no name has been saved. [officeName] keeps the notification
  /// useful when the user has configured more than one workplace.
  Future<void> showAttendanceRecorded(
    String name,
    String officeName,
    DateTime timestamp, {
    int id = 0,
  }) async {
    final content = buildAttendanceNotificationContent(
      name: name,
      officeName: officeName,
      timestamp: timestamp,
    );

    // Apple platforms use the same concise hierarchy. Avoiding an image
    // attachment keeps their expanded notifications compact as well.
    final darwinDetails = DarwinNotificationDetails(
      subtitle: '${content.shortDate} · ${content.office}',
      threadIdentifier: 'attendance-recorded',
    );

    await _plugin.show(
      id: id,
      title: content.title,
      body: content.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'attendance_channel',
          'Attendance',
          channelDescription: 'Notifies when office attendance is recorded',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          // A small garden flower beside the text; a bundled drawable, so it
          // loads in the background isolate without touching Flutter assets.
          largeIcon: const DrawableResourceAndroidBitmap('notification_flower'),
          styleInformation: BigTextStyleInformation(
            content.expandedBody,
            contentTitle: content.title,
          ),
          category: AndroidNotificationCategory.status,
          color: const Color(0xFF315741),
          onlyAlertOnce: true,
          ticker: 'Checked in at ${content.office}',
          when: timestamp.millisecondsSinceEpoch,
        ),
        iOS: darwinDetails,
        macOS: darwinDetails,
      ),
    );
  }
}

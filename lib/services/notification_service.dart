import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../themes/bird_art.dart';
import 'database_service.dart';

class AttendanceNotificationContent {
  const AttendanceNotificationContent({
    required this.title,
    required this.body,
    required this.expandedBody,
    required this.date,
    required this.office,
  });

  final String title;
  final String body;
  final String expandedBody;
  final String date;
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

  /// Writes the selected theme's bird illustration to a temp file so Android
  /// can use it as a small notification accent. It is deliberately not used as
  /// a big picture: square bird artwork creates an oversized, mostly empty
  /// expanded notification. Always best-effort; the notification still shows
  /// if assets are unavailable in a background isolate.
  Future<String?> _birdImagePath() async {
    try {
      final themeId =
          await DatabaseService.instance.getSetting('theme_id') ?? 'bee_eater';
      final asset = birdAssetForTheme(themeId);
      if (asset == null) return null;
      final bytes = await rootBundle.load(asset);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/notif_bird_$themeId.png');
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
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

    // The selected theme's bird is a small accent, not expanded artwork.
    final birdPath = await _birdImagePath();
    final birdBitmap = birdPath == null
        ? null
        : FilePathAndroidBitmap(birdPath);

    // Apple platforms use the same concise hierarchy. Avoiding an image
    // attachment keeps their expanded notifications compact as well.
    final darwinDetails = DarwinNotificationDetails(
      subtitle: '${content.date} · ${content.office}',
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
          largeIcon: birdBitmap,
          styleInformation: BigTextStyleInformation(
            content.expandedBody,
            contentTitle: content.title,
          ),
          category: AndroidNotificationCategory.status,
          color: const Color(0xFF16835A),
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

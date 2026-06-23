import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../themes/bird_art.dart';
import 'database_service.dart';

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
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
      ),
    );
  }

  /// Writes the selected theme's bird illustration to a temp file so it can be
  /// used as the notification's image, and returns its path (or null if there's
  /// no artwork or it can't be loaded — e.g. from a background isolate without
  /// asset access). Always best-effort: the notification still shows without it.
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

    // The selected theme's bird, shown as the notification's icon/image.
    final birdPath = await _birdImagePath();
    final birdBitmap = birdPath == null ? null : FilePathAndroidBitmap(birdPath);

    // iOS and macOS share the same Darwin details (with the bird as an
    // attachment when available).
    final darwinDetails = birdPath != null
        ? DarwinNotificationDetails(
            attachments: [DarwinNotificationAttachment(birdPath)],
          )
        : const DarwinNotificationDetails();

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
          largeIcon: birdBitmap,
          // Expandable body so the full message + emoji show; when a bird image
          // is available, expand to show it large (with the text underneath).
          styleInformation: birdBitmap != null
              ? BigPictureStyleInformation(
                  birdBitmap,
                  largeIcon: birdBitmap,
                  contentTitle: title,
                  summaryText: body,
                  hideExpandedLargeIcon: true,
                )
              : BigTextStyleInformation(body, contentTitle: title),
        ),
        iOS: darwinDetails,
        macOS: darwinDetails,
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Opens the *specific* Android system settings screen for each permission the
/// app needs, instead of the generic app-info page. On non-Android platforms
/// (or if a native intent fails) it falls back to the standard app settings.
class AppSettingsService {
  static const _channel = MethodChannel('app.attendance/settings');

  /// App details page — where the user can set location to "Allow all the time".
  static Future<void> openLocation() => _open('openLocationSettings');

  /// The app's notification settings page.
  static Future<void> openNotifications() => _open('openNotificationSettings');

  /// The "ignore battery optimisation" request dialog for this app.
  static Future<void> openBatteryOptimization() =>
      _open('openBatteryOptimizationSettings');

  static Future<void> _open(String method) async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod<void>(method);
        return;
      } catch (_) {
        // Fall through to the generic settings page below.
      }
    }
    await openAppSettings();
  }
}

import 'package:permission_handler/permission_handler.dart';

import 'app_settings_service.dart';

/// Runtime permission requests for everything automatic check-in depends on:
/// background ("always") location, notifications, and (Android) exemption from
/// battery optimisation.
///
/// Each request shows the system dialog when the OS still allows it, and falls
/// back to opening the relevant settings page once the permission has been
/// permanently denied (the OS stops showing the dialog after repeated denials,
/// and Android 11+ only grants "Allow all the time" from the settings page).
class PermissionService {
  PermissionService._();

  /// Foreground location first (required before "always" can be requested),
  /// then the background upgrade. Returns true when "always" is granted.
  static Future<bool> requestLocationAlways() async {
    final foreground = await Permission.locationWhenInUse.request();
    if (foreground.isPermanentlyDenied) {
      await AppSettingsService.openLocation();
      return false;
    }
    if (!foreground.isGranted) return false;

    final always = await Permission.locationAlways.request();
    if (always.isGranted) return true;
    if (always.isPermanentlyDenied) {
      await AppSettingsService.openLocation();
    }
    return false;
  }

  /// Android 13+ requires a runtime request before any notification is shown;
  /// on iOS this surfaces the standard notification prompt.
  static Future<bool> requestNotifications() async {
    final status = await Permission.notification.request();
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      await AppSettingsService.openNotifications();
    }
    return false;
  }

  /// Shows Android's "let app ignore battery optimisations" dialog so the
  /// 15-minute background check keeps firing. Android only.
  static Future<bool> requestIgnoreBatteryOptimizations() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      await AppSettingsService.openBatteryOptimization();
    }
    return false;
  }
}

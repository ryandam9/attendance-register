import 'package:flutter/foundation.dart' show debugPrint;
import 'package:intl/intl.dart';
import 'package:network_info_plus/network_info_plus.dart';

import '../models/attendance_record.dart';
import '../models/office_location.dart';
import 'database_service.dart';
import 'notification_service.dart';

/// A second way to record office attendance: when the device is connected to
/// one of an office's configured Wi-Fi networks, the day is marked even if GPS
/// is off or the geofence never fired (indoors, location disabled). Mirrors the
/// guards in LocationService so a Wi-Fi check never overwrites a holiday,
/// resurrects a deleted day, or double-records.
class WifiService {
  WifiService._();
  static final WifiService instance = WifiService._();

  final NetworkInfo _networkInfo = NetworkInfo();

  /// The SSID the device is currently connected to, normalised — or null when
  /// not on Wi-Fi, or when the OS withholds the name (needs location
  /// permission + location services on, Android 10+).
  Future<String?> connectedSsid() async {
    try {
      return normalizeSsid(await _networkInfo.getWifiName());
    } catch (e) {
      debugPrint('Wi-Fi SSID lookup failed: $e');
      return null;
    }
  }

  /// Cleans a raw SSID for matching: Android wraps it in double quotes, and
  /// returns sentinel values like `<unknown ssid>` when it can't read it.
  /// Returns null for anything that isn't a usable network name.
  static String? normalizeSsid(String? raw) {
    if (raw == null) return null;
    var s = raw.trim();
    // Strip the surrounding quotes Android adds, e.g. "MyNetwork".
    if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
      s = s.substring(1, s.length - 1).trim();
    }
    if (s.isEmpty || s == '<unknown ssid>' || s == '0x') return null;
    return s;
  }

  /// The first office whose configured Wi-Fi list contains [ssid]
  /// (case-insensitive), or null. Pure so it can be unit-tested without the
  /// platform plugin.
  static OfficeLocation? matchOffice(
    String? ssid,
    List<OfficeLocation> offices,
  ) {
    if (ssid == null) return null;
    final target = ssid.toLowerCase();
    for (final office in offices) {
      for (final name in office.wifiNames) {
        if (name.trim().toLowerCase() == target) return office;
      }
    }
    return null;
  }

  /// Checks the connected network against every office's Wi-Fi list and records
  /// today's attendance at the first match. Returns the office recorded at, or
  /// null when there is no match or the day is already settled. Never prompts
  /// for permission. When [notify] is true a system notification is shown (used
  /// by the periodic background-style check); the foreground caller passes false
  /// and shows in-app feedback instead.
  static Future<OfficeLocation?> performWifiCheck({required bool notify}) async {
    final db = DatabaseService.instance;
    final offices = await db.getOfficeLocations();
    // No point reading the SSID if no office opted into Wi-Fi check-in.
    final withWifi = offices.where((o) => o.wifiNames.isNotEmpty).toList();
    if (withWifi.isEmpty) return null;

    final ssid = await instance.connectedSsid();
    final office = matchOffice(ssid, withWifi);
    if (office == null || office.id == null) return null;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // A holiday / leave day is the user's call — never override it.
    if (await db.getSpecialDayForDate(today) != null) return null;
    // The user deleted today's record — don't resurrect it.
    if (await db.isAutoCheckInDismissed(today)) return null;
    // Already recorded today — this is what "stop scanning for the day" means.
    if (await db.hasAttendanceForDate(today, office.id!)) return null;

    final id = await db.insertAttendanceRecord(
      AttendanceRecord(
        date: today,
        officeLocationId: office.id!,
        timestamp: DateTime.now(),
        reason: 'Auto check-in (Wi-Fi)',
      ),
    );

    if (id != null && id > 0) {
      if (notify) {
        final userName = await db.getSetting('user_name');
        await NotificationService.instance.showAttendanceRecorded(
          userName != null && userName.isNotEmpty ? userName : 'there',
          DateTime.now(),
          id: office.id!,
        );
      }
      return office;
    }
    return null;
  }
}

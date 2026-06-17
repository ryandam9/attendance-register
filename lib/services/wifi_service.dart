import 'package:flutter/foundation.dart' show debugPrint;
import 'package:intl/intl.dart';
import 'package:wifi_scan/wifi_scan.dart';

import '../models/attendance_record.dart';
import '../models/office_location.dart';
import 'database_service.dart';
import 'notification_service.dart';

/// A second way to record office attendance: when one of an office's configured
/// Wi-Fi networks is *visible nearby* (it does NOT need to be connected — you
/// can stay on mobile data), the day is marked even if GPS is off or the
/// geofence never fired (indoors, location disabled). Mirrors the guards in
/// LocationService so a Wi-Fi check never overwrites a holiday, resurrects a
/// deleted day, or double-records.
///
/// Android only: scanning visible networks is unsupported on iOS, where this
/// degrades to a no-op (the geofence path still works there).
class WifiService {
  WifiService._();
  static final WifiService instance = WifiService._();

  /// SSIDs of the Wi-Fi networks the OS currently sees as available, normalised
  /// and de-duplicated. This *reads the system's existing list* — it does not
  /// initiate a scan, so there is nothing for the user to trigger and no
  /// throttling to fight. Empty when the list can't be read (permission denied,
  /// location services off, unsupported platform). Never throws.
  Future<List<String>> nearbySsids() async {
    try {
      // Just read what the OS already has from its own periodic scanning. We
      // deliberately do NOT call startScan(): the app should passively observe
      // the available-networks list, not force a hardware scan.
      if (await WiFiScan.instance.canGetScannedResults() !=
          CanGetScannedResults.yes) {
        return const [];
      }
      final results = await WiFiScan.instance.getScannedResults();
      final seen = <String>{};
      final ssids = <String>[];
      for (final ap in results) {
        final ssid = normalizeSsid(ap.ssid);
        if (ssid != null && seen.add(ssid.toLowerCase())) ssids.add(ssid);
      }
      return ssids;
    } catch (e) {
      debugPrint('Reading Wi-Fi networks failed: $e');
      return const [];
    }
  }

  /// Cleans a raw SSID for matching: trims, strips the surrounding quotes some
  /// platforms add, and rejects empty / hidden-network sentinels. Returns null
  /// for anything that isn't a usable network name.
  static String? normalizeSsid(String? raw) {
    if (raw == null) return null;
    var s = raw.trim();
    if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
      s = s.substring(1, s.length - 1).trim();
    }
    if (s.isEmpty || s == '<unknown ssid>' || s == '0x') return null;
    return s;
  }

  /// The first office that has at least one configured network present in
  /// [scannedSsids] (case-insensitive), or null. Pure so it can be unit-tested
  /// without the platform plugin.
  static OfficeLocation? matchOffice(
    Iterable<String> scannedSsids,
    List<OfficeLocation> offices,
  ) {
    final nearby = scannedSsids
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toSet();
    if (nearby.isEmpty) return null;
    for (final office in offices) {
      for (final name in office.wifiNames) {
        if (nearby.contains(name.trim().toLowerCase())) return office;
      }
    }
    return null;
  }

  /// Reads the OS's available-networks list and records today's attendance at
  /// the first office whose Wi-Fi is in range. Returns the office recorded at,
  /// or null when there is no match or the day is already settled. Fully
  /// passive: no scan is triggered, no permission is prompted. When [notify] is
  /// true a system notification is shown (the periodic check); the foreground
  /// caller passes false and shows in-app feedback instead.
  static Future<OfficeLocation?> performWifiCheck({required bool notify}) async {
    final db = DatabaseService.instance;
    final offices = await db.getOfficeLocations();
    // No point reading the list if no office opted into Wi-Fi check-in.
    final withWifi = offices.where((o) => o.wifiNames.isNotEmpty).toList();
    if (withWifi.isEmpty) return null;

    final ssids = await instance.nearbySsids();
    final office = matchOffice(ssids, withWifi);
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

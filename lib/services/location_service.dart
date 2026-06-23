import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:native_geofence/native_geofence.dart' as nf;

import '../models/attendance_record.dart';
import '../models/office_location.dart';
import 'database_service.dart';
import 'notification_service.dart';

/// native_geofence implements only Android and iOS. On every other platform its
/// method-channel calls fail with a channelError, so the app skips them: macOS
/// and desktop rely on the foreground check instead, and Linux/Windows/web have
/// no location stack at all.
bool get isGeofencingSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Invoked by the native_geofence plugin in a background isolate when the OS
/// reports a geofence crossing — including with the app fully killed.
@pragma('vm:entry-point')
Future<void> geofenceTriggered(nf.GeofenceCallbackParams params) async {
  // An uncaught exception here dies silently in the background isolate, so
  // guard the whole callback.
  try {
    if (params.event != nf.GeofenceEvent.enter) return;
    // This isolate has no plugin state from the main isolate — initialise
    // notifications explicitly rather than relying on persisted settings.
    await NotificationService.instance.initialize();
    for (final activeGeofence in params.geofences) {
      final officeId = int.tryParse(activeGeofence.id);
      if (officeId != null) {
        await LocationService.instance.recordGeofenceCheckIn(officeId);
      }
    }
  } catch (e) {
    debugPrint('Geofence callback failed: $e');
  }
}

/// A reverse-geocoded location: a human-readable [address] plus the structured
/// [state]/[country] fields the holiday importer matches on.
class GeoPlace {
  final String? address;
  final String? state;
  final String? country;
  const GeoPlace({this.address, this.state, this.country});
}

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  /// Ask for foreground location permission. Returns true when granted.
  Future<bool> requestPermission() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  /// True when a position can be read right now without prompting the user.
  static Future<bool> _hasPermissionSilently() async {
    try {
      final perm = await Geolocator.checkPermission();
      return perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse;
    } catch (_) {
      // geolocator has no Linux/Windows implementation — treat as no access.
      return false;
    }
  }

  Future<Position?> getCurrentPosition() async {
    if (!await requestPermission()) return null;
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  double distanceTo(double lat1, double lon1, double lat2, double lon2) =>
      Geolocator.distanceBetween(lat1, lon1, lat2, lon2);

  /// Reverse-geocodes [lat]/[lng] into a display address plus the structured
  /// [GeoPlace.state] (administrative area) and [GeoPlace.country] (ISO code)
  /// used to match the office against public-holidays.csv.
  Future<GeoPlace?> placeFromCoordinates(double lat, double lng) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lng);
      if (marks.isEmpty) return null;
      final p = marks.first;
      final address = [p.street, p.locality, p.postalCode, p.country]
          .where((s) => s != null && s.isNotEmpty)
          .join(', ');
      String? nonEmpty(String? s) => (s == null || s.isEmpty) ? null : s;
      return GeoPlace(
        address: address.isEmpty ? null : address,
        state: nonEmpty(p.administrativeArea),
        country: nonEmpty(p.isoCountryCode),
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<Location>?> coordinatesFromAddress(String address) async {
    try {
      return await locationFromAddress(address);
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasAlwaysPermission() async {
    final perm = await Geolocator.checkPermission();
    return perm == LocationPermission.always;
  }

  Future<void> syncGeofences() async {
    if (!isGeofencingSupported) return;
    try {
      final alwaysGranted = await hasAlwaysPermission();
      if (!alwaysGranted) {
        await nf.NativeGeofenceManager.instance.removeAllGeofences();
        return;
      }

      final db = DatabaseService.instance;
      final offices = await db.getOfficeLocations();
      final activeGeofences = await nf.NativeGeofenceManager.instance.getRegisteredGeofences();
      final activeIds = activeGeofences.map((g) => g.id).toSet();
      final dbIds = offices.map((o) => o.id.toString()).toSet();

      // 1. Remove geofences that are no longer in the DB
      for (final activeId in activeIds) {
        if (!dbIds.contains(activeId)) {
          await nf.NativeGeofenceManager.instance.removeGeofenceById(activeId);
        }
      }

      // 2. Register/re-register geofences for offices in DB
      for (final office in offices) {
        if (!office.hasLocation) continue; // manual-only office: no geofence
        final idStr = office.id.toString();
        if (activeIds.contains(idStr)) {
          await nf.NativeGeofenceManager.instance.removeGeofenceById(idStr);
        }

        final geofence = nf.Geofence(
          id: idStr,
          location: nf.Location(latitude: office.latitude, longitude: office.longitude),
          radiusMeters: office.radius,
          triggers: {
            nf.GeofenceEvent.enter,
          },
          iosSettings: const nf.IosGeofenceSettings(
            initialTrigger: true,
          ),
          // No expiration: a geofence that silently lapses would stop auto
          // check-in for a user who hasn't opened the app in a while.
          // loiteringDelay is omitted — it only applies to dwell triggers.
          androidSettings: const nf.AndroidGeofenceSettings(
            initialTriggers: {nf.GeofenceEvent.enter},
            notificationResponsiveness: Duration(seconds: 30),
          ),
        );

        await nf.NativeGeofenceManager.instance.createGeofence(geofence, geofenceTriggered);
      }
    } catch (e, stack) {
      // Gracefully log instead of crashing (important for offline/testing/unsupported platform scenarios)
      debugPrint('Failed to sync geofences: $e\n$stack');
    }
  }

  Future<void> recordGeofenceCheckIn(int officeId) async {
    final db = DatabaseService.instance;
    final office = await db.getOfficeLocation(officeId);
    if (office == null) return;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Check special day conflicts (holidays, leaves, etc.)
    if (await db.getSpecialDayForDate(today) != null) return;

    // The user deleted today's record — don't resurrect it.
    if (await db.isAutoCheckInDismissed(today)) return;

    // Check if attendance already recorded today for this office
    if (await db.hasAttendanceForDate(today, officeId)) return;

    // Insert attendance record
    final id = await db.insertAttendanceRecord(
      AttendanceRecord(
        date: today,
        officeLocationId: officeId,
        timestamp: DateTime.now(),
        reason: 'Auto check-in',
      ),
    );

    if (id != null && id > 0) {
      final userName = await db.getSetting('user_name');
      await NotificationService.instance.showAttendanceRecorded(
        userName != null && userName.isNotEmpty ? userName : 'there',
        DateTime.now(),
        id: officeId,
      );
    }
  }

  /// Same check, run when the app is opened or resumed. Catches the days the
  /// background task missed (killed by the OS, battery optimisation, iOS task
  /// scheduling) — if the user is standing in the office with the app open,
  /// attendance is recorded on the spot. Returns the office recorded at, or
  /// null. Skips the system notification: the caller shows in-app feedback.
  static Future<OfficeLocation?> performForegroundCheck() async {
    await instance.syncGeofences();
    return _checkAndRecord(notify: false);
  }

  /// Core auto check-in: if the current position is within the radius of a
  /// registered office and today is unmarked, record attendance. Never prompts
  /// for permission — runs only when location access was already granted.
  static Future<OfficeLocation?> _checkAndRecord({required bool notify}) async {
    final db = DatabaseService.instance;
    final offices = await db.getOfficeLocations();
    if (offices.isEmpty) return null;
    if (!await _hasPermissionSilently()) return null;

    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } catch (_) {
      return null;
    }

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // A day already marked as a public holiday, sick leave or misc leave is
    // off-limits to auto check-in — the user owns that decision and can change
    // it manually. Mirrors the specialDayConflict guard in manualCheckIn so an
    // automatic geo check never silently overwrites a (blue) public holiday
    // with "Attended".
    if (await db.getSpecialDayForDate(today) != null) return null;

    // The user deleted today's record — don't resurrect it.
    if (await db.isAutoCheckInDismissed(today)) return null;

    OfficeLocation? recordedAt;
    for (final office in offices) {
      if (!office.hasLocation) continue; // manual-only office
      if (await db.hasAttendanceForDate(today, office.id!)) continue;

      final distance = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        office.latitude,
        office.longitude,
      );

      if (distance <= office.radius) {
        // insertAttendanceRecord uses ConflictAlgorithm.ignore: it returns the
        // new row id on a real insert, 0 when a record for today already exists
        // (duplicate ignored), or null on error. Only notify when a row was
        // actually written, so the user never sees "attendance recorded" twice
        // for the same day — even if two runs race past the
        // hasAttendanceForDate guard above.
        final id = await db.insertAttendanceRecord(
          AttendanceRecord(
            date: today,
            officeLocationId: office.id!,
            timestamp: DateTime.now(),
            reason: 'Auto check-in',
          ),
        );
        if (id != null && id > 0) {
          recordedAt ??= office;
          if (notify) {
            final userName = await db.getSetting('user_name');
            await NotificationService.instance.showAttendanceRecorded(
              userName != null && userName.isNotEmpty ? userName : 'there',
              DateTime.now(),
              id: office.id!,
            );
          }
        }
      }
    }
    return recordedAt;
  }
}

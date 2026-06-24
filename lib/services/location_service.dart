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

/// Why a foreground (app-open) auto check-in did or didn't happen, so the UI can
/// explain itself instead of failing silently.
enum ForegroundCheckStatus {
  /// Attendance was recorded for today.
  recorded,

  /// There are offices but none has a saved location to match against — add
  /// coordinates (edit the office → "Use current location").
  noOfficeLocation,

  /// Location permission hasn't been granted, so the position can't be read.
  permissionDenied,

  /// Nothing to report and nothing wrong: no offices, already recorded, the
  /// position couldn't be read, or you're simply not at an office. The UI stays
  /// quiet for this — it would otherwise nag on every app open.
  none,
}

class ForegroundCheck {
  final ForegroundCheckStatus status;
  final OfficeLocation? office; // set when [status] is recorded
  const ForegroundCheck(this.status, {this.office});
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
      final address = [
        p.street,
        p.locality,
        p.postalCode,
        p.country,
      ].where((s) => s != null && s.isNotEmpty).join(', ');
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
      final activeGeofences = await nf.NativeGeofenceManager.instance
          .getRegisteredGeofences();
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
          location: nf.Location(
            latitude: office.latitude,
            longitude: office.longitude,
          ),
          radiusMeters: office.radius,
          triggers: {nf.GeofenceEvent.enter},
          iosSettings: const nf.IosGeofenceSettings(initialTrigger: true),
          // No expiration: a geofence that silently lapses would stop auto
          // check-in for a user who hasn't opened the app in a while.
          // loiteringDelay is omitted — it only applies to dwell triggers.
          androidSettings: const nf.AndroidGeofenceSettings(
            initialTriggers: {nf.GeofenceEvent.enter},
            notificationResponsiveness: Duration(seconds: 30),
          ),
        );

        await nf.NativeGeofenceManager.instance.createGeofence(
          geofence,
          geofenceTriggered,
        );
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
  /// attendance is recorded on the spot. Skips the system notification — the
  /// caller shows in-app feedback based on the returned [ForegroundCheck].
  static Future<ForegroundCheck> performForegroundCheck() async {
    await instance.syncGeofences();

    final offices = await DatabaseService.instance.getOfficeLocations();
    if (offices.isEmpty) {
      return const ForegroundCheck(ForegroundCheckStatus.none);
    }
    // Actionable: no office has coordinates to match against.
    if (offices.every((o) => !o.hasLocation)) {
      return const ForegroundCheck(ForegroundCheckStatus.noOfficeLocation);
    }

    // Request permission first. On macOS the authorization is often "not yet
    // determined" on launch, which checkPermission()/getCurrentPosition() report
    // as denied — only requestPermission() resolves it (it shows a system prompt
    // ONLY when undetermined; never when already granted or denied). This is why
    // the setup "Use current location" flow worked but the silent check didn't.
    LocationPermission perm;
    try {
      perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
    } catch (e) {
      perm = LocationPermission.unableToDetermine;
      debugPrint('[autocheck] permission request threw: $e');
    }

    bool serviceEnabled = false;
    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
    } catch (_) {}
    // Diagnostic: shows in the `flutter run` console so the actual state is
    // visible instead of guessed.
    debugPrint('[autocheck] serviceEnabled=$serviceEnabled permission=$perm');

    final granted =
        perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
    if (!granted) {
      final denied =
          perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever;
      return ForegroundCheck(
        denied
            ? ForegroundCheckStatus.permissionDenied
            : ForegroundCheckStatus.none,
      );
    }

    // macOS often fails the FIRST getCurrentPosition right after launch — the
    // location manager is still warming up, so it throws "User denied" even
    // though permission is granted — then succeeds. Retry once before giving up.
    Position? pos;
    for (var attempt = 1; attempt <= 2 && pos == null; attempt++) {
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 20),
          ),
        );
      } catch (e) {
        debugPrint(
          '[autocheck] getCurrentPosition attempt $attempt failed: $e',
        );
        pos = null;
        if (attempt < 2) {
          await Future.delayed(const Duration(milliseconds: 800));
        }
      }
    }
    if (pos == null) {
      return const ForegroundCheck(ForegroundCheckStatus.none);
    }
    debugPrint('[autocheck] position=${pos.latitude},${pos.longitude}');

    final office = await _recordForPosition(pos, notify: false);
    return office != null
        ? ForegroundCheck(ForegroundCheckStatus.recorded, office: office)
        : const ForegroundCheck(ForegroundCheckStatus.none);
  }

  /// Opens the OS location settings (so the user can enable Location Services /
  /// grant access). Best-effort across platforms.
  static Future<void> openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
    } catch (_) {
      try {
        await Geolocator.openAppSettings();
      } catch (_) {
        // No settings UI available on this platform — nothing more we can do.
      }
    }
  }

  /// Records attendance for an already-read [pos] if it's within an office's
  /// radius and today is still open. Returns the office recorded at, or null.
  static Future<OfficeLocation?> _recordForPosition(
    Position pos, {
    required bool notify,
  }) async {
    final db = DatabaseService.instance;
    final offices = await db.getOfficeLocations();
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

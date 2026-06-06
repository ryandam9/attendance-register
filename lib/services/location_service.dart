import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../models/attendance_record.dart';
import 'database_service.dart';
import 'notification_service.dart';

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

  /// Ask for "always" (background) permission — call after foreground is granted.
  Future<bool> requestAlwaysPermission() async {
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.whileInUse) {
      // On Android 10+ the OS shows its own "upgrade to always" dialog.
      await Geolocator.requestPermission();
    }
    return (await Geolocator.checkPermission()) == LocationPermission.always;
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

  Future<String?> addressFromCoordinates(double lat, double lng) async {
    return (await placeFromCoordinates(lat, lng))?.address;
  }

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

  /// Executed by WorkManager every 15 minutes in the background.
  /// Must be a static method so it can be called from the top-level callback.
  static Future<void> performBackgroundCheck() async {
    final db = DatabaseService.instance;
    final offices = await db.getOfficeLocations();
    if (offices.isEmpty) return;

    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } catch (_) {
      return;
    }

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    for (final office in offices) {
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
        // for the same day — even if two background runs race past the
        // hasAttendanceForDate guard above.
        final id = await db.insertAttendanceRecord(
          AttendanceRecord(
            date: today,
            officeLocationId: office.id!,
            timestamp: DateTime.now(),
          ),
        );
        if (id != null && id > 0) {
          await NotificationService.instance.showAttendanceRecorded(office.name);
        }
      }
    }
  }
}

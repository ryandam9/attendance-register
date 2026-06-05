import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../models/attendance_record.dart';
import 'database_service.dart';
import 'notification_service.dart';

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
    try {
      final marks = await placemarkFromCoordinates(lat, lng);
      if (marks.isEmpty) return null;
      final p = marks.first;
      return [p.street, p.locality, p.postalCode, p.country]
          .where((s) => s != null && s.isNotEmpty)
          .join(', ');
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
        await db.insertAttendanceRecord(
          AttendanceRecord(
            date: today,
            officeLocationId: office.id!,
            timestamp: DateTime.now(),
          ),
        );
        await NotificationService.instance.showAttendanceRecorded(office.name);
      }
    }
  }
}

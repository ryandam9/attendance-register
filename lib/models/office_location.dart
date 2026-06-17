import 'package:flutter/foundation.dart' show listEquals;

class OfficeLocation {
  final int? id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double radius; // metres
  // Resolved from the geocoder when the address is looked up. Used to match the
  // office against public-holidays.csv. [country] is an ISO country code (e.g.
  // "AU", "US"); [state] is the administrative area (e.g. "Western Australia").
  // Both are null for offices saved before structured location was captured.
  final String? country;
  final String? state;
  // Wi-Fi network names (SSIDs) that identify this office. When the device is
  // connected to any of these, attendance can be recorded without GPS — a
  // second check-in path for when location is off or indoors. Empty when the
  // user has not configured any. Stored as a newline-joined string in the
  // `wifi_names` column.
  final List<String> wifiNames;

  const OfficeLocation({
    this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.radius = 200.0,
    this.country,
    this.state,
    this.wifiNames = const [],
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'radius': radius,
    'country': country,
    'state': state,
    'wifi_names': encodeWifiNames(wifiNames),
  };

  factory OfficeLocation.fromMap(Map<String, dynamic> map) => OfficeLocation(
    id: map['id'] as int?,
    name: map['name'] as String,
    address: map['address'] as String,
    latitude: map['latitude'] as double,
    longitude: map['longitude'] as double,
    radius: map['radius'] as double,
    country: map['country'] as String?,
    state: map['state'] as String?,
    wifiNames: decodeWifiNames(map['wifi_names'] as String?),
  );

  /// Joins configured SSIDs into the single TEXT column. Empty list → null so
  /// the column stays unset rather than storing an empty string.
  static String? encodeWifiNames(List<String> names) {
    final cleaned = names.map((s) => s.trim()).where((s) => s.isNotEmpty);
    return cleaned.isEmpty ? null : cleaned.join('\n');
  }

  /// Splits the stored column back into a trimmed, de-duplicated list. Tolerates
  /// null (column absent / never set) and blank lines.
  static List<String> decodeWifiNames(String? stored) {
    if (stored == null || stored.trim().isEmpty) return const [];
    final seen = <String>{};
    final result = <String>[];
    for (final line in stored.split('\n')) {
      final name = line.trim();
      if (name.isNotEmpty && seen.add(name.toLowerCase())) result.add(name);
    }
    return result;
  }

  OfficeLocation copyWith({
    int? id,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    double? radius,
    String? country,
    String? state,
    List<String>? wifiNames,
  }) => OfficeLocation(
    id: id ?? this.id,
    name: name ?? this.name,
    address: address ?? this.address,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    radius: radius ?? this.radius,
    country: country ?? this.country,
    state: state ?? this.state,
    wifiNames: wifiNames ?? this.wifiNames,
  );

  // Value equality so widgets that compare offices (e.g. the office dropdown
  // matching its selected value against the items list) don't depend on
  // instance identity.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfficeLocation &&
          other.id == id &&
          other.name == name &&
          other.address == address &&
          other.latitude == latitude &&
          other.longitude == longitude &&
          other.radius == radius &&
          other.country == country &&
          other.state == state &&
          listEquals(other.wifiNames, wifiNames);

  @override
  int get hashCode => Object.hash(
    id, name, address, latitude, longitude, radius, country, state,
    Object.hashAll(wifiNames),
  );
}

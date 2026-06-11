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

  const OfficeLocation({
    this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.radius = 200.0,
    this.country,
    this.state,
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
  );

  OfficeLocation copyWith({
    int? id,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    double? radius,
    String? country,
    String? state,
  }) => OfficeLocation(
    id: id ?? this.id,
    name: name ?? this.name,
    address: address ?? this.address,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    radius: radius ?? this.radius,
    country: country ?? this.country,
    state: state ?? this.state,
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
          other.state == state;

  @override
  int get hashCode => Object.hash(
    id, name, address, latitude, longitude, radius, country, state,
  );
}

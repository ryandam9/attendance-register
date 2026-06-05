class OfficeLocation {
  final int? id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double radius; // metres

  const OfficeLocation({
    this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.radius = 200.0,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'radius': radius,
  };

  factory OfficeLocation.fromMap(Map<String, dynamic> map) => OfficeLocation(
    id: map['id'] as int?,
    name: map['name'] as String,
    address: map['address'] as String,
    latitude: map['latitude'] as double,
    longitude: map['longitude'] as double,
    radius: map['radius'] as double,
  );

  OfficeLocation copyWith({
    int? id,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    double? radius,
  }) => OfficeLocation(
    id: id ?? this.id,
    name: name ?? this.name,
    address: address ?? this.address,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    radius: radius ?? this.radius,
  );
}

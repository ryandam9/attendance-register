import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_register/models/office_location.dart';

void main() {
  group('OfficeLocation', () {
    const office = OfficeLocation(
      id: 1,
      name: 'HQ',
      address: '123 Main St, Springfield',
      latitude: 37.7749,
      longitude: -122.4194,
      radius: 300.0,
    );

    test('toMap includes all fields', () {
      final map = office.toMap();

      expect(map['id'], 1);
      expect(map['name'], 'HQ');
      expect(map['address'], '123 Main St, Springfield');
      expect(map['latitude'], 37.7749);
      expect(map['longitude'], -122.4194);
      expect(map['radius'], 300.0);
    });

    test('fromMap round-trip', () {
      final restored = OfficeLocation.fromMap(office.toMap());

      expect(restored.id, office.id);
      expect(restored.name, office.name);
      expect(restored.address, office.address);
      expect(restored.latitude, office.latitude);
      expect(restored.longitude, office.longitude);
      expect(restored.radius, office.radius);
    });

    test('default radius is 200', () {
      const loc = OfficeLocation(
        name: 'Branch',
        address: '1 Branch Rd',
        latitude: 0,
        longitude: 0,
      );

      expect(loc.radius, 200.0);
    });

    test('copyWith changes only specified fields', () {
      final updated = office.copyWith(name: 'Downtown Office', radius: 150.0);

      expect(updated.id, office.id);
      expect(updated.name, 'Downtown Office');
      expect(updated.address, office.address);
      expect(updated.latitude, office.latitude);
      expect(updated.longitude, office.longitude);
      expect(updated.radius, 150.0);
    });

    test('copyWith with no args is identical', () {
      final copy = office.copyWith();

      expect(copy.id, office.id);
      expect(copy.name, office.name);
      expect(copy.address, office.address);
      expect(copy.latitude, office.latitude);
      expect(copy.longitude, office.longitude);
      expect(copy.radius, office.radius);
    });

    test('copyWith can update id', () {
      final loc = office.copyWith(id: 99);
      expect(loc.id, 99);
    });

    test('fromMap with null id', () {
      final map = office.toMap()..['id'] = null;
      final restored = OfficeLocation.fromMap(map);
      expect(restored.id, isNull);
    });

    test('equal field-by-field copies are == with matching hashCode', () {
      final copy = office.copyWith();
      expect(copy, equals(office));
      expect(copy.hashCode, office.hashCode);
    });

    test('differing fields break equality', () {
      expect(office.copyWith(name: 'Branch'), isNot(equals(office)));
      expect(office.copyWith(radius: 50.0), isNot(equals(office)));
      expect(office.copyWith(id: 2), isNot(equals(office)));
    });
  });
}

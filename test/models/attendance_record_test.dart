import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_register/models/attendance_record.dart';

void main() {
  group('AttendanceRecord', () {
    final ts = DateTime(2025, 6, 15, 9, 0, 0);

    test('toMap includes all fields', () {
      final record = AttendanceRecord(
        id: 1,
        date: '2025-06-15',
        officeLocationId: 42,
        timestamp: ts,
        reason: 'Team meeting',
      );

      final map = record.toMap();

      expect(map['id'], 1);
      expect(map['date'], '2025-06-15');
      expect(map['office_location_id'], 42);
      expect(map['timestamp'], ts.toIso8601String());
      expect(map['reason'], 'Team meeting');
    });

    test('toMap with null reason', () {
      final record = AttendanceRecord(
        date: '2025-06-15',
        officeLocationId: 1,
        timestamp: ts,
      );

      expect(record.toMap()['reason'], isNull);
    });

    test('fromMap round-trips with reason', () {
      final original = AttendanceRecord(
        id: 7,
        date: '2025-06-15',
        officeLocationId: 3,
        timestamp: ts,
        reason: 'Missed auto check-in',
      );

      final restored = AttendanceRecord.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.date, original.date);
      expect(restored.officeLocationId, original.officeLocationId);
      expect(restored.timestamp, original.timestamp);
      expect(restored.reason, original.reason);
    });

    test('fromMap round-trips without reason', () {
      final original = AttendanceRecord(
        id: 2,
        date: '2025-01-10',
        officeLocationId: 1,
        timestamp: ts,
      );

      final restored = AttendanceRecord.fromMap(original.toMap());

      expect(restored.reason, isNull);
    });

    test('fromMap handles null reason column from DB', () {
      final map = {
        'id': 5,
        'date': '2025-03-01',
        'office_location_id': 2,
        'timestamp': ts.toIso8601String(),
        'reason': null,
      };

      final record = AttendanceRecord.fromMap(map);
      expect(record.reason, isNull);
    });

    test('timestamp is parsed correctly', () {
      final map = {
        'id': 1,
        'date': '2025-06-15',
        'office_location_id': 1,
        'timestamp': '2025-06-15T09:00:00.000',
        'reason': null,
      };

      final record = AttendanceRecord.fromMap(map);
      expect(record.timestamp.year, 2025);
      expect(record.timestamp.month, 6);
      expect(record.timestamp.day, 15);
    });
  });
}

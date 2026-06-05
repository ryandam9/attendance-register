class AttendanceRecord {
  final int? id;
  final String date; // YYYY-MM-DD
  final int officeLocationId;
  final DateTime timestamp;
  final String? reason;

  const AttendanceRecord({
    this.id,
    required this.date,
    required this.officeLocationId,
    required this.timestamp,
    this.reason,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': date,
    'office_location_id': officeLocationId,
    'timestamp': timestamp.toIso8601String(),
    'reason': reason,
  };

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) => AttendanceRecord(
    id: map['id'] as int?,
    date: map['date'] as String,
    officeLocationId: map['office_location_id'] as int,
    timestamp: DateTime.parse(map['timestamp'] as String),
    reason: map['reason'] as String?,
  );
}

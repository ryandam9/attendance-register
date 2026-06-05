enum DayType { holiday, sickLeave }

class SpecialDay {
  final int? id;
  final String date; // YYYY-MM-DD
  final DayType type;
  final String? note;

  const SpecialDay({
    this.id,
    required this.date,
    required this.type,
    this.note,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': date,
    'type': type.name,
    'note': note,
  };

  factory SpecialDay.fromMap(Map<String, dynamic> map) => SpecialDay(
    id: map['id'] as int?,
    date: map['date'] as String,
    type: DayType.values.byName(map['type'] as String),
    note: map['note'] as String?,
  );
}

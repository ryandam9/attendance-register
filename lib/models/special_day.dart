/// A day that is explicitly not an office-attendance day.
///
/// [holiday] and [sickLeave] are excluded from the attendance percentage
/// denominator (they are not working days you were expected to attend).
/// [notAttended] is a normal working day you simply did not attend — it stays
/// in the denominator and therefore lowers your percentage.
enum DayType { holiday, sickLeave, notAttended }

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

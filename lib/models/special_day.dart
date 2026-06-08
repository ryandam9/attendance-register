/// A day that is explicitly not an office-attendance day.
///
/// [holiday], [sickLeave], [annualLeave] and [carersLeave] are excluded from
/// the attendance percentage denominator (they are not working days you were
/// expected to attend) — see [excludedFromAttendanceDenominator].
/// [workFromHome] and [notAttended] are normal working days you did not attend
/// the office — they stay in the denominator and therefore lower your
/// percentage.
enum DayType { holiday, sickLeave, annualLeave, carersLeave, workFromHome, notAttended }

/// Day types that count as time you were not expected to be at the office, and
/// are therefore subtracted from the attendance-percentage denominator. Keeping
/// this in one place means every new leave type only has to be listed here to
/// inherit the existing percentage rule. [DayType.workFromHome] and
/// [DayType.notAttended] are deliberately absent — they stay in the denominator
/// and lower your percentage.
const excludedFromAttendanceDenominator = <DayType>{
  DayType.holiday,
  DayType.sickLeave,
  DayType.annualLeave,
  DayType.carersLeave,
};

/// Where a [SpecialDay] came from. [manual] entries are created (or edited) by
/// the user and always take priority — the public-holiday importer never
/// overwrites or removes them. [auto] entries are inserted by the importer from
/// `public-holidays.csv` and may be refreshed by it.
enum DaySource { manual, auto }

class SpecialDay {
  final int? id;
  final String date; // YYYY-MM-DD
  final DayType type;
  final String? note;
  final DaySource source;

  const SpecialDay({
    this.id,
    required this.date,
    required this.type,
    this.note,
    this.source = DaySource.manual,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': date,
    'type': type.name,
    'note': note,
    'source': source.name,
  };

  factory SpecialDay.fromMap(Map<String, dynamic> map) => SpecialDay(
    id: map['id'] as int?,
    date: map['date'] as String,
    type: DayType.values.byName(map['type'] as String),
    note: map['note'] as String?,
    // Rows written before the `source` column existed (pre-v4) read back null —
    // treat those as manual so the importer leaves them untouched.
    source: map['source'] == null
        ? DaySource.manual
        : DaySource.values.byName(map['source'] as String),
  );
}

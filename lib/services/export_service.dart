import '../helpers/day_type_helper.dart';
import 'database_service.dart';

/// A built export: the CSV text plus how many day-rows it contains.
typedef ExportResult = ({String csv, int rows});

/// Builds a CSV backup of every recorded day — attendance (with office name)
/// and special days (leave/holidays/WFH) — newest first. The attendance data
/// is the user's proof of office days, so it must be possible to get it out of
/// the on-device database; the caller puts the CSV on the clipboard or shares
/// it.
class ExportService {
  ExportService._();

  static Future<ExportResult> buildCsv() async {
    final db = DatabaseService.instance;

    final lines = <({String date, String status, String office, String comment})>[];
    for (final office in await db.getOfficeLocations()) {
      for (final r in await db.getAllAttendanceRecords(office.id!)) {
        lines.add((
          date: r.date,
          status: 'Attended',
          office: office.name,
          comment: r.reason ?? '',
        ));
      }
    }
    for (final s in await db.getAllSpecialDays()) {
      lines.add((
        date: s.date,
        status: s.type.label,
        office: '',
        comment: s.note ?? '',
      ));
    }
    lines.sort((a, b) => b.date.compareTo(a.date));

    final buf = StringBuffer('date,status,office,comment\n');
    for (final l in lines) {
      buf.writeln(
        [l.date, l.status, l.office, l.comment].map(_field).join(','),
      );
    }
    return (csv: buf.toString(), rows: lines.length);
  }

  /// Quotes a CSV field when it contains a delimiter, quote or newline.
  static String _field(String s) =>
      s.contains(',') || s.contains('"') || s.contains('\n')
          ? '"${s.replaceAll('"', '""')}"'
          : s;
}

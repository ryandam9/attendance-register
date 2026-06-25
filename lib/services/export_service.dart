import 'package:excel/excel.dart';

import '../helpers/day_type_helper.dart';
import 'database_service.dart';

/// One exported day-row: a date with its status, office and free-text comment.
typedef ExportRow = ({
  String date,
  String status,
  String office,
  String comment,
});

/// A built CSV export: the text plus how many day-rows it contains.
typedef ExportResult = ({String csv, int rows});

/// A built Excel export: the .xlsx bytes plus how many day-rows it contains.
typedef XlsxResult = ({List<int> bytes, int rows});

/// Builds backups of every recorded day — attendance (with office name) and
/// special days (leave/holidays/WFH), newest first. The attendance data is the
/// user's proof of office days, so it must be possible to get it out of the
/// on-device database; the caller puts the CSV on the clipboard, or saves/shares
/// the .xlsx workbook.
class ExportService {
  ExportService._();

  static const _header = ['date', 'status', 'office', 'comment'];

  /// Gathers every attendance + special day, newest first.
  static Future<List<ExportRow>> collectRows() async {
    final db = DatabaseService.instance;
    final rows = <ExportRow>[];
    for (final office in await db.getOfficeLocations()) {
      for (final r in await db.getAllAttendanceRecords(office.id!)) {
        rows.add((
          date: r.date,
          status: 'Attended',
          office: office.name,
          comment: r.reason ?? '',
        ));
      }
    }
    for (final s in await db.getAllSpecialDays()) {
      rows.add((
        date: s.date,
        status: s.type.label,
        office: '',
        comment: s.note ?? '',
      ));
    }
    rows.sort((a, b) => b.date.compareTo(a.date));
    return rows;
  }

  static Future<ExportResult> buildCsv() async {
    final rows = await collectRows();
    final buf = StringBuffer('${_header.join(',')}\n');
    for (final r in rows) {
      buf.writeln(
        [r.date, r.status, r.office, r.comment].map(_field).join(','),
      );
    }
    return (csv: buf.toString(), rows: rows.length);
  }

  /// Builds an `.xlsx` workbook with a header row and one row per recorded day.
  static Future<XlsxResult> buildXlsx() async {
    final rows = await collectRows();

    final excel = Excel.createExcel();
    // Rename the auto-created default sheet rather than leave a stray "Sheet1".
    excel.rename(excel.getDefaultSheet()!, 'History');
    final sheet = excel['History'];

    sheet.appendRow([for (final h in _header) TextCellValue(h)]);
    for (final r in rows) {
      sheet.appendRow([
        TextCellValue(r.date),
        TextCellValue(r.status),
        TextCellValue(r.office),
        TextCellValue(r.comment),
      ]);
    }

    final bytes = excel.save() ?? <int>[];
    return (bytes: bytes, rows: rows.length);
  }

  /// Quotes a CSV field when it contains a delimiter, quote or newline.
  static String _field(String s) =>
      s.contains(',') || s.contains('"') || s.contains('\n')
      ? '"${s.replaceAll('"', '""')}"'
      : s;
}

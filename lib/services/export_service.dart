import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../helpers/day_type_helper.dart';
import '../models/special_day.dart';
import 'database_service.dart';

/// One complete exported history row. Attendance and special days share this
/// shape so the workbook can preserve their useful provenance in one timeline.
typedef ExportRow = ({
  DateTime date,
  String status,
  String office,
  String source,
  DateTime? recordedAt,
  String comment,
});

typedef ExportResult = ({String csv, int rows});
typedef XlsxResult = ({List<int> bytes, int rows});

/// Builds complete backups across every office. CSV remains a compact clipboard
/// backup; Excel is a polished worksheet with an overview and full history.
class ExportService {
  ExportService._();

  static const _csvHeader = ['date', 'status', 'office', 'comment'];
  static const _historyHeader = [
    'Date',
    'Day',
    'Status',
    'Office',
    'Entry source',
    'Recorded at',
    'Notes',
  ];
  static final _dateKeyFormat = DateFormat('yyyy-MM-dd');
  static final _exportedAtFormat = DateFormat('d MMM yyyy, h:mm a');
  static final _dayFormat = DateFormat('EEEE');
  static final _rangeFormat = DateFormat('d MMM yyyy');

  /// Gathers every attendance record from every office plus every special day,
  /// newest first. No screen filter or selected-office filter is applied.
  static Future<List<ExportRow>> collectRows() async {
    final db = DatabaseService.instance;
    final rows = <ExportRow>[];
    for (final office in await db.getOfficeLocations()) {
      for (final r in await db.getAllAttendanceRecords(office.id!)) {
        rows.add((
          date: DateTime.parse(r.date),
          status: 'Attended',
          office: office.name,
          source: r.reason == 'Auto check-in'
              ? 'Automatic check-in'
              : 'Manual entry',
          recordedAt: r.timestamp,
          comment: r.reason ?? '',
        ));
      }
    }
    for (final s in await db.getAllSpecialDays()) {
      rows.add((
        date: DateTime.parse(s.date),
        status: s.type.label,
        office: '',
        source: s.source == DaySource.auto
            ? 'GitHub holiday import'
            : 'Manual entry',
        recordedAt: null,
        comment: s.note ?? '',
      ));
    }
    rows.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      return (b.recordedAt ?? b.date).compareTo(a.recordedAt ?? a.date);
    });
    return rows;
  }

  static Future<ExportResult> buildCsv() async {
    final rows = await collectRows();
    final buf = StringBuffer('${_csvHeader.join(',')}\n');
    for (final r in rows) {
      buf.writeln(
        [
          _dateKeyFormat.format(r.date),
          r.status,
          r.office,
          r.comment,
        ].map(_field).join(','),
      );
    }
    return (csv: buf.toString(), rows: rows.length);
  }

  /// Builds a conservative single-sheet `.xlsx` workbook. Keeping the export
  /// to the original worksheet and avoiding merged cells/custom number formats
  /// prevents the worksheet XML repairs reported by Microsoft Excel for Mac.
  /// [exportedAt] is injectable so workbook metadata is testable.
  static Future<XlsxResult> buildXlsx({DateTime? exportedAt}) async {
    final rows = await collectRows();
    final generatedAt = exportedAt ?? DateTime.now();
    final excel = Excel.createExcel();
    excel.rename(excel.getDefaultSheet()!, 'History');
    _buildHistory(excel['History'], rows, generatedAt);
    return (bytes: excel.save() ?? <int>[], rows: rows.length);
  }

  static void _buildHistory(
    Sheet sheet,
    List<ExportRow> rows,
    DateTime exportedAt,
  ) {
    sheet.setDefaultRowHeight(22);
    const widths = [18.0, 14.0, 22.0, 24.0, 24.0, 22.0, 42.0];
    for (var column = 0; column < widths.length; column++) {
      sheet.setColumnWidth(column, widths[column]);
    }

    _put(
      sheet,
      0,
      0,
      TextCellValue('Attendance Register'),
      _titleStyle,
    );
    sheet.setRowHeight(0, 34);
    _put(
      sheet,
      0,
      1,
      TextCellValue(
        'Complete history • ${rows.length} '
        '${rows.length == 1 ? 'entry' : 'entries'} • '
        'Exported ${_exportedAtFormat.format(exportedAt)}',
      ),
      _subtitleStyle,
    );
    sheet.setRowHeight(1, 24);

    final officeDays = rows.where((row) => row.status == 'Attended').length;
    final range = rows.isEmpty
        ? 'No recorded dates'
        : '${_rangeFormat.format(rows.last.date)} – '
              '${_rangeFormat.format(rows.first.date)}';
    _put(sheet, 0, 3, TextCellValue('Overview'), _sectionStyle);
    final metrics = <(String, CellValue)>[
      ('Total history entries', IntCellValue(rows.length)),
      ('Office attendance days', IntCellValue(officeDays)),
      ('Other recorded days', IntCellValue(rows.length - officeDays)),
      ('Date range', TextCellValue(range)),
    ];
    for (var i = 0; i < metrics.length; i++) {
      final row = 4 + i;
      _put(sheet, 0, row, TextCellValue(metrics[i].$1), _metricLabelStyle);
      _put(sheet, 1, row, metrics[i].$2, _metricValueStyle);
    }

    _tableHeader(sheet, 9, _historyHeader);
    sheet.setRowHeight(9, 28);

    for (var i = 0; i < rows.length; i++) {
      final item = rows[i];
      final row = 10 + i;
      final bodyStyle = _stripedBodyStyle(i.isOdd);
      _put(
        sheet,
        0,
        row,
        TextCellValue(_dateKeyFormat.format(item.date)),
        bodyStyle,
      );
      _put(
        sheet,
        1,
        row,
        TextCellValue(_dayFormat.format(item.date)),
        bodyStyle,
      );
      _put(
        sheet,
        2,
        row,
        TextCellValue(item.status),
        _statusStyle(item.status),
      );
      _put(
        sheet,
        3,
        row,
        item.office.isEmpty ? null : TextCellValue(item.office),
        bodyStyle,
      );
      _put(sheet, 4, row, TextCellValue(item.source), bodyStyle);
      _put(
        sheet,
        5,
        row,
        item.recordedAt == null
            ? null
            : TextCellValue(_exportedAtFormat.format(item.recordedAt!)),
        bodyStyle,
      );
      _put(
        sheet,
        6,
        row,
        item.comment.isEmpty ? null : TextCellValue(item.comment),
        bodyStyle.copyWith(textWrappingVal: TextWrapping.WrapText),
      );
      sheet.setRowHeight(row, 28);
    }
  }

  static void _put(
    Sheet sheet,
    int column,
    int row,
    CellValue? value,
    CellStyle style,
  ) {
    sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
      value,
      cellStyle: style,
    );
  }

  static void _tableHeader(Sheet sheet, int row, List<String> headings) {
    for (var column = 0; column < headings.length; column++) {
      _put(
        sheet,
        column,
        row,
        headings[column].isEmpty ? null : TextCellValue(headings[column]),
        _headerStyle,
      );
    }
  }

  static final _thinBorder = Border(
    borderStyle: BorderStyle.Thin,
    borderColorHex: ExcelColor.grey300,
  );
  static final _titleStyle = CellStyle(
    backgroundColorHex: ExcelColor.blue900,
    fontColorHex: ExcelColor.white,
    fontSize: 20,
    bold: true,
    verticalAlign: VerticalAlign.Center,
  );
  static final _subtitleStyle = CellStyle(
    backgroundColorHex: ExcelColor.blue50,
    fontColorHex: ExcelColor.blue900,
    fontSize: 11,
    italic: true,
    verticalAlign: VerticalAlign.Center,
  );
  static final _sectionStyle = CellStyle(
    backgroundColorHex: ExcelColor.blue100,
    fontColorHex: ExcelColor.blue900,
    fontSize: 12,
    bold: true,
    verticalAlign: VerticalAlign.Center,
    bottomBorder: _thinBorder,
  );
  static final _headerStyle = CellStyle(
    backgroundColorHex: ExcelColor.blue900,
    fontColorHex: ExcelColor.white,
    bold: true,
    verticalAlign: VerticalAlign.Center,
    bottomBorder: _thinBorder,
  );
  static final _metricLabelStyle = CellStyle(
    backgroundColorHex: ExcelColor.grey100,
    fontColorHex: ExcelColor.blue900,
    bold: true,
    verticalAlign: VerticalAlign.Center,
    bottomBorder: _thinBorder,
  );
  static final _metricValueStyle = CellStyle(
    fontColorHex: ExcelColor.blue900,
    bold: true,
    verticalAlign: VerticalAlign.Center,
    bottomBorder: _thinBorder,
  );
  static CellStyle _stripedBodyStyle(bool shaded) => CellStyle(
    backgroundColorHex: shaded ? ExcelColor.blue50 : ExcelColor.white,
    verticalAlign: VerticalAlign.Center,
    bottomBorder: _thinBorder,
  );

  static CellStyle _statusStyle(String status) {
    final (background, foreground) = switch (status) {
      'Attended' => (ExcelColor.green100, ExcelColor.green900),
      'Work from Home' => (ExcelColor.cyan100, ExcelColor.cyan900),
      'Public Holiday' => (ExcelColor.blue100, ExcelColor.blue900),
      'Sick Leave' => (ExcelColor.orange100, ExcelColor.deepOrange900),
      'Annual Leave' => (ExcelColor.purple100, ExcelColor.purple900),
      "Carer's Leave" => (ExcelColor.pink100, ExcelColor.pink900),
      _ => (ExcelColor.grey200, ExcelColor.grey900),
    };
    return CellStyle(
      backgroundColorHex: background,
      fontColorHex: foreground,
      bold: true,
      verticalAlign: VerticalAlign.Center,
      bottomBorder: _thinBorder,
    );
  }

  static String _field(String s) =>
      s.contains(',') || s.contains('"') || s.contains('\n')
      ? '"${s.replaceAll('"', '""')}"'
      : s;
}

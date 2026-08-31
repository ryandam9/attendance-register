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
/// backup; Excel is a polished workbook with a summary and full History sheet.
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

  /// Builds an `.xlsx` workbook with a Summary sheet and a complete History
  /// sheet. [exportedAt] is injectable so workbook metadata is testable.
  static Future<XlsxResult> buildXlsx({DateTime? exportedAt}) async {
    final rows = await collectRows();
    final generatedAt = exportedAt ?? DateTime.now();
    final excel = Excel.createExcel();
    excel.rename(excel.getDefaultSheet()!, 'Summary');
    _buildSummary(excel['Summary'], rows, generatedAt);
    _buildHistory(excel['History'], rows, generatedAt);
    excel.setDefaultSheet('Summary');
    return (bytes: excel.save() ?? <int>[], rows: rows.length);
  }

  static void _buildSummary(
    Sheet sheet,
    List<ExportRow> rows,
    DateTime exportedAt,
  ) {
    sheet.setDefaultRowHeight(20);
    sheet.setColumnWidth(0, 28);
    sheet.setColumnWidth(1, 18);
    sheet.setColumnWidth(2, 18);
    sheet.setColumnWidth(3, 24);

    _mergedHeading(
      sheet,
      start: 'A1',
      end: 'D1',
      text: 'Attendance Register',
      style: _titleStyle,
    );
    sheet.setRowHeight(0, 34);
    _mergedHeading(
      sheet,
      start: 'A2',
      end: 'D2',
      text: 'Complete history export • ${_exportedAtFormat.format(exportedAt)}',
      style: _subtitleStyle,
    );
    sheet.setRowHeight(1, 24);

    _sectionHeading(sheet, 3, 'At a glance', 4);
    final officeDays = rows.where((r) => r.status == 'Attended').length;
    final range = rows.isEmpty
        ? 'No recorded dates'
        : '${_rangeFormat.format(rows.last.date)} – ${_rangeFormat.format(rows.first.date)}';
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
      if (i == metrics.length - 1) {
        sheet.merge(
          CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row),
          CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row),
        );
        sheet.setMergedCellStyle(
          CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row),
          _metricValueStyle,
        );
      }
    }

    final statusCounts = <String, int>{};
    for (final row in rows) {
      statusCounts.update(row.status, (n) => n + 1, ifAbsent: () => 1);
    }
    const statusOrder = [
      'Attended',
      'Work from Home',
      'Public Holiday',
      'Sick Leave',
      'Annual Leave',
      "Carer's Leave",
      'Misc Leave',
    ];
    _sectionHeading(sheet, 9, 'Status breakdown', 4);
    _tableHeader(sheet, 10, const ['Status', 'Days', '% of history', '']);
    var nextRow = 11;
    for (final status in statusOrder) {
      final count = statusCounts[status];
      if (count == null) continue;
      _put(sheet, 0, nextRow, TextCellValue(status), _statusStyle(status));
      _put(sheet, 1, nextRow, IntCellValue(count), _centredBodyStyle);
      _put(
        sheet,
        2,
        nextRow,
        TextCellValue('${(count / rows.length * 100).toStringAsFixed(1)}%'),
        _centredBodyStyle,
      );
      _put(sheet, 3, nextRow, null, _bodyStyle);
      nextRow++;
    }

    final officeCounts = <String, int>{};
    for (final row in rows.where((r) => r.office.isNotEmpty)) {
      officeCounts.update(row.office, (n) => n + 1, ifAbsent: () => 1);
    }
    nextRow++;
    _sectionHeading(sheet, nextRow++, 'Office attendance', 4);
    _tableHeader(sheet, nextRow++, const ['Office', 'Days', '', '']);
    if (officeCounts.isEmpty) {
      _put(
        sheet,
        0,
        nextRow++,
        TextCellValue('No office attendance recorded'),
        _mutedBodyStyle,
      );
    } else {
      final offices = officeCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final office in offices) {
        _put(sheet, 0, nextRow, TextCellValue(office.key), _bodyStyle);
        _put(
          sheet,
          1,
          nextRow++,
          IntCellValue(office.value),
          _centredBodyStyle,
        );
      }
    }

    nextRow += 2;
    _mergedHeading(
      sheet,
      start: 'A${nextRow + 1}',
      end: 'D${nextRow + 1}',
      text:
          'The History sheet contains every attendance, leave, holiday and work-from-home entry.',
      style: _footerStyle,
    );
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

    _mergedHeading(
      sheet,
      start: 'A1',
      end: 'G1',
      text: 'Complete Attendance History',
      style: _titleStyle,
    );
    sheet.setRowHeight(0, 34);
    _mergedHeading(
      sheet,
      start: 'A2',
      end: 'G2',
      text:
          '${rows.length} ${rows.length == 1 ? 'entry' : 'entries'} • Exported ${_exportedAtFormat.format(exportedAt)}',
      style: _subtitleStyle,
    );
    sheet.setRowHeight(1, 24);
    sheet.setRowHeight(2, 8);
    _tableHeader(sheet, 3, _historyHeader);
    sheet.setRowHeight(3, 28);

    for (var i = 0; i < rows.length; i++) {
      final item = rows[i];
      final row = 4 + i;
      final bodyStyle = _stripedBodyStyle(i.isOdd);
      _put(
        sheet,
        0,
        row,
        DateCellValue.fromDateTime(item.date),
        bodyStyle.copyWith(
          numberFormat: const CustomDateTimeNumFormat(
            formatCode: 'ddd, dd mmm yyyy',
          ),
        ),
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
            : DateTimeCellValue.fromDateTime(item.recordedAt!),
        bodyStyle.copyWith(
          numberFormat: const CustomDateTimeNumFormat(
            formatCode: 'dd mmm yyyy, h:mm AM/PM',
          ),
        ),
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

  static void _mergedHeading(
    Sheet sheet, {
    required String start,
    required String end,
    required String text,
    required CellStyle style,
  }) {
    final startCell = CellIndex.indexByString(start);
    sheet.merge(
      startCell,
      CellIndex.indexByString(end),
      customValue: TextCellValue(text),
    );
    sheet.setMergedCellStyle(startCell, style);
    // excel 4.x applies a merged-range style to the surrounding cells, but the
    // start cell can lose its font flags when the workbook is encoded. Style
    // that value explicitly so headings stay bold in Excel and after decoding.
    sheet.updateCell(startCell, TextCellValue(text), cellStyle: style);
  }

  static void _sectionHeading(Sheet sheet, int row, String text, int columns) {
    final start = CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row);
    sheet.merge(
      start,
      CellIndex.indexByColumnRow(columnIndex: columns - 1, rowIndex: row),
      customValue: TextCellValue(text),
    );
    sheet.setMergedCellStyle(start, _sectionStyle);
    sheet.updateCell(start, TextCellValue(text), cellStyle: _sectionStyle);
    sheet.setRowHeight(row, 26);
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
  static final _bodyStyle = CellStyle(
    verticalAlign: VerticalAlign.Center,
    bottomBorder: _thinBorder,
  );
  static final _centredBodyStyle = CellStyle(
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    bottomBorder: _thinBorder,
  );
  static final _mutedBodyStyle = CellStyle(
    fontColorHex: ExcelColor.grey600,
    italic: true,
    verticalAlign: VerticalAlign.Center,
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
  static final _footerStyle = CellStyle(
    backgroundColorHex: ExcelColor.grey100,
    fontColorHex: ExcelColor.grey700,
    italic: true,
    verticalAlign: VerticalAlign.Center,
    textWrapping: TextWrapping.WrapText,
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

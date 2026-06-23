import 'package:intl/intl.dart';

/// The month a financial (reporting) year begins on. The Explain page lets the
/// user report a "year" either as a calendar year or an Australian-style
/// financial year.
enum FinancialYearStart {
  january(DateTime.january, 'January – December'),
  october(DateTime.october, 'October – September');

  final int startMonth;
  final String label;
  const FinancialYearStart(this.startMonth, this.label);

  /// Stable key for persistence (survives enum reordering, unlike the index).
  static FinancialYearStart fromName(String? name) =>
      values.firstWhere((v) => v.name == name, orElse: () => january);
}

/// Whether a [ReportPeriod] spans a single month or a whole financial year.
enum PeriodKind { month, year }

/// A selectable reporting window for the Explain page — either one calendar
/// month or one financial year — that knows its own inclusive date range and a
/// human-readable label, and can step to the previous/next window.
class ReportPeriod {
  final PeriodKind kind;

  /// For [PeriodKind.month] any day inside the month; for [PeriodKind.year] any
  /// day inside the financial year. Normalised via [start]/[end].
  final DateTime anchor;

  /// Only meaningful for [PeriodKind.year]; ignored for a month.
  final FinancialYearStart financialYearStart;

  const ReportPeriod({
    required this.kind,
    required this.anchor,
    this.financialYearStart = FinancialYearStart.january,
  });

  /// The period containing today, of [kind], for the given [fyStart].
  factory ReportPeriod.current(
    PeriodKind kind, {
    FinancialYearStart fyStart = FinancialYearStart.january,
  }) => ReportPeriod(
    kind: kind,
    anchor: DateTime.now(),
    financialYearStart: fyStart,
  );

  /// The financial year that [anchor] falls in, expressed as the calendar year
  /// the year *starts* in. For an October start, Jan–Sep belongs to the prior
  /// year's window (which began the previous October).
  int get _fyStartYear {
    if (financialYearStart == FinancialYearStart.january) return anchor.year;
    return anchor.month >= FinancialYearStart.october.startMonth
        ? anchor.year
        : anchor.year - 1;
  }

  /// First day of the window (inclusive).
  DateTime get start => switch (kind) {
    PeriodKind.month => DateTime(anchor.year, anchor.month, 1),
    PeriodKind.year => DateTime(_fyStartYear, financialYearStart.startMonth, 1),
  };

  /// Last day of the window (inclusive).
  DateTime get end => switch (kind) {
    // Day 0 of next month == last day of this month.
    PeriodKind.month => DateTime(anchor.year, anchor.month + 1, 0),
    PeriodKind.year =>
      financialYearStart == FinancialYearStart.january
          ? DateTime(_fyStartYear, 12, 31)
          // Day before the next financial year starts.
          : DateTime(
              _fyStartYear + 1,
              FinancialYearStart.october.startMonth,
              0,
            ),
  };

  String get label => switch (kind) {
    PeriodKind.month => DateFormat('MMMM yyyy').format(start),
    PeriodKind.year =>
      financialYearStart == FinancialYearStart.january
          ? '$_fyStartYear'
          : 'FY $_fyStartYear–${_fyStartYear + 1}',
  };

  /// The same window shifted by [delta] units (months or years).
  ReportPeriod _shifted(int delta) {
    final next = switch (kind) {
      PeriodKind.month => DateTime(anchor.year, anchor.month + delta, 1),
      PeriodKind.year => DateTime(anchor.year + delta, anchor.month, 1),
    };
    return ReportPeriod(
      kind: kind,
      anchor: next,
      financialYearStart: financialYearStart,
    );
  }

  ReportPeriod get previous => _shifted(-1);
  ReportPeriod get next => _shifted(1);

  ReportPeriod withKind(PeriodKind newKind) => ReportPeriod(
    kind: newKind,
    anchor: anchor,
    financialYearStart: financialYearStart,
  );

  ReportPeriod withFinancialYearStart(FinancialYearStart fyStart) =>
      ReportPeriod(kind: kind, anchor: anchor, financialYearStart: fyStart);

  /// True when this window contains today — used to disable the "next" arrow so
  /// the user cannot page into the future.
  bool get isCurrent {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return !today.isBefore(start) && !today.isAfter(end);
  }
}

import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_register/models/report_period.dart';

void main() {
  group('ReportPeriod (month)', () {
    test('spans the first to last day of the anchor month', () {
      const p = ReportPeriod(kind: PeriodKind.month, anchor: DateTime(2026, 2, 14));
      expect(p.start, DateTime(2026, 2, 1));
      expect(p.end, DateTime(2026, 2, 28)); // 2026 is not a leap year
      expect(p.label, 'February 2026');
    });

    test('previous / next step by one month across a year boundary', () {
      const p = ReportPeriod(kind: PeriodKind.month, anchor: DateTime(2026, 1, 10));
      expect(p.previous.start, DateTime(2025, 12, 1));
      expect(p.next.start, DateTime(2026, 2, 1));
    });
  });

  group('ReportPeriod (year, January start)', () {
    test('spans the calendar year', () {
      const p = ReportPeriod(
        kind: PeriodKind.year,
        anchor: DateTime(2026, 6, 8),
        financialYearStart: FinancialYearStart.january,
      );
      expect(p.start, DateTime(2026, 1, 1));
      expect(p.end, DateTime(2026, 12, 31));
      expect(p.label, '2026');
    });
  });

  group('ReportPeriod (year, October start)', () {
    test('a date in Oct–Dec belongs to the window that starts that October', () {
      const p = ReportPeriod(
        kind: PeriodKind.year,
        anchor: DateTime(2026, 11, 1),
        financialYearStart: FinancialYearStart.october,
      );
      expect(p.start, DateTime(2026, 10, 1));
      expect(p.end, DateTime(2027, 9, 30));
      expect(p.label, 'FY 2026–2027');
    });

    test('a date in Jan–Sep belongs to the prior October window', () {
      const p = ReportPeriod(
        kind: PeriodKind.year,
        anchor: DateTime(2026, 3, 15),
        financialYearStart: FinancialYearStart.october,
      );
      expect(p.start, DateTime(2025, 10, 1));
      expect(p.end, DateTime(2026, 9, 30));
      expect(p.label, 'FY 2025–2026');
    });

    test('next steps to the following financial year', () {
      const p = ReportPeriod(
        kind: PeriodKind.year,
        anchor: DateTime(2026, 11, 1),
        financialYearStart: FinancialYearStart.october,
      );
      expect(p.next.start, DateTime(2027, 10, 1));
      expect(p.next.end, DateTime(2028, 9, 30));
    });
  });

  group('FinancialYearStart.fromName', () {
    test('round-trips known names and falls back to January', () {
      expect(FinancialYearStart.fromName('october'), FinancialYearStart.october);
      expect(FinancialYearStart.fromName('january'), FinancialYearStart.january);
      expect(FinancialYearStart.fromName(null), FinancialYearStart.january);
      expect(FinancialYearStart.fromName('garbage'), FinancialYearStart.january);
    });
  });
}

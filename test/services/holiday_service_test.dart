import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_register/models/office_location.dart';
import 'package:attendance_register/services/holiday_service.dart';

const _csv = '''
country,state,date,desc
AU,Western Australia,2026-01-01,New Year's Day
AU,Western Australia,2026-06-01,Western Australia Day
AU,New South Wales,2026-01-26,Australia Day
US,California,2026-07-04,Independence Day
''';

OfficeLocation _office({String? country, String? state}) => OfficeLocation(
  name: 'Office',
  address: 'somewhere',
  latitude: 0,
  longitude: 0,
  country: country,
  state: state,
);

void main() {
  group('parseCsv', () {
    test('skips the header and parses every data row', () {
      final rows = HolidayService.parseCsv(_csv);
      expect(rows, hasLength(4));
      expect(rows.first.country, 'AU');
      expect(rows.first.state, 'Western Australia');
      expect(rows.first.date, '2026-01-01');
      expect(rows.first.desc, "New Year's Day");
    });

    test('ignores blank lines and rows with too few columns', () {
      final rows = HolidayService.parseCsv(
        'country,state,date,desc\n\nAU,WA\nUS,California,2026-07-04,July 4\n',
      );
      expect(rows, hasLength(1));
      expect(rows.single.country, 'US');
    });

    test('preserves commas inside the description', () {
      final rows = HolidayService.parseCsv(
        'country,state,date,desc\nUS,California,2026-12-25,Christmas, observed',
      );
      expect(rows.single.desc, 'Christmas, observed');
    });

    test('skips rows whose date is not YYYY-MM-DD', () {
      final rows = HolidayService.parseCsv(
        'country,state,date,desc\n'
        'AU,Victoria,June 1,Bad format\n'
        'AU,Victoria,2026-6-1,Unpadded\n'
        'AU,Victoria,2026-06-01,Good\n',
      );
      expect(rows, hasLength(1));
      expect(rows.single.date, '2026-06-01');
    });

    test('skips rows whose date is not a real calendar day', () {
      // DateTime.parse would silently normalise 2026-02-30 to 2026-03-02 —
      // the row must be rejected, not imported under a shifted date.
      final rows = HolidayService.parseCsv(
        'country,state,date,desc\n'
        'AU,Victoria,2026-02-30,Impossible\n'
        'AU,Victoria,2026-13-01,Bad month\n',
      );
      expect(rows, isEmpty);
    });
  });

  group('officeKeys', () {
    test('includes only offices with both country and state', () {
      final keys = HolidayService.officeKeys([
        _office(country: 'AU', state: 'Western Australia'),
        _office(country: 'AU', state: null),
        _office(country: null, state: 'Victoria'),
      ]);
      expect(keys, hasLength(1));
    });
  });

  group('matchingHolidays', () {
    test('matches case-insensitively and excludes other regions', () {
      final rows = HolidayService.parseCsv(_csv);
      final keys = HolidayService.officeKeys([
        _office(country: 'au', state: 'western australia'),
      ]);

      final matches = HolidayService.matchingHolidays(rows, keys);
      expect(matches, hasLength(2));
      expect(
        matches.map((h) => h.date),
        containsAll(['2026-01-01', '2026-06-01']),
      );
    });

    test('returns nothing when no office region matches', () {
      final rows = HolidayService.parseCsv(_csv);
      final keys = HolidayService.officeKeys([
        _office(country: 'GB', state: 'England'),
      ]);
      expect(HolidayService.matchingHolidays(rows, keys), isEmpty);
    });
  });
}

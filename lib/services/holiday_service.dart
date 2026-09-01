import 'dart:convert';
import 'dart:io';

import '../models/office_location.dart';
import '../models/special_day.dart';
import 'database_service.dart';

/// One row of `public-holidays.csv`: `country,state,date,desc`.
class HolidayRow {
  final String country; // ISO code, e.g. "AU"
  final String state; // administrative area, e.g. "Western Australia"
  final String date; // YYYY-MM-DD
  final String desc;

  const HolidayRow({
    required this.country,
    required this.state,
    required this.date,
    required this.desc,
  });
}

/// How a holiday sync ended, so the UI can tell "nothing new to add" apart from
/// "nothing could ever match".
enum HolidaySyncOutcome {
  /// Holidays were imported.
  added,

  /// Everything that matched is already on the calendar.
  unchanged,

  /// There are no offices yet — nothing to match holidays against.
  noOffices,

  /// Offices exist, but none records both a country and a state, so no CSV row
  /// can match. Usually an office whose region could not be resolved when it
  /// was saved: away from Android and iOS the app falls back to an HTTP
  /// geocoder, and when that returns nothing the office keeps its coordinates
  /// but no region — silently ruling out every holiday.
  noRegion,

  /// The published list could not be fetched (offline, or the request failed).
  unavailable,
}

/// The result of a [HolidayService.sync]: how many holidays were imported, and
/// why that number is what it is.
class HolidaySyncResult {
  final int inserted;
  final HolidaySyncOutcome outcome;
  const HolidaySyncResult(this.inserted, this.outcome);
}

/// Reads a public-holiday list published in the GitHub repo and, for every
/// holiday whose country+state matches one of the user's registered offices,
/// inserts an auto-sourced [SpecialDay] of type [DayType.holiday] — which the
/// calendar then highlights and the percentage maths excludes.
///
/// Manual entries always win: the importer never overwrites a manual special
/// day, a day you actually attended, or a holiday you deliberately removed.
class HolidayService {
  HolidayService._();
  static final HolidayService instance = HolidayService._();

  /// Raw CSV in the repo. Pinned to `main` so released builds read the
  /// published list rather than a feature branch.
  static const csvUrl =
      'https://raw.githubusercontent.com/ryandam9/attendance-register/main/public-holidays.csv';

  static final _dateRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// True when [s] is a real calendar date in `YYYY-MM-DD` form. DateTime.parse
  /// alone is not enough: it normalises out-of-range values (2026-02-30 →
  /// 2026-03-02), so round-trip the parsed date back to the string.
  static bool _isValidDate(String s) {
    if (!_dateRe.hasMatch(s)) return false;
    final d = DateTime.tryParse(s);
    if (d == null) return false;
    return s ==
        '${d.year.toString().padLeft(4, '0')}-'
            '${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}';
  }

  /// Parses CSV text into rows, skipping a header line, blanks and rows whose
  /// date is not a valid `YYYY-MM-DD` (a malformed date would otherwise be
  /// stored and crash date parsing in the calendar/history views). Commas
  /// inside the trailing `desc` field are preserved.
  static List<HolidayRow> parseCsv(String csv) {
    final rows = <HolidayRow>[];
    for (final raw in const LineSplitter().convert(csv)) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final parts = line.split(',');
      if (parts.length < 3) continue;
      final country = parts[0].trim();
      // Skip the header row (and anything obviously not a data row).
      if (country.toLowerCase() == 'country') continue;
      final date = parts[2].trim();
      if (!_isValidDate(date)) continue;
      rows.add(
        HolidayRow(
          country: country,
          state: parts[1].trim(),
          date: date,
          desc: parts.length > 3 ? parts.sublist(3).join(',').trim() : '',
        ),
      );
    }
    return rows;
  }

  /// Case-insensitive country+state key used to match a holiday to an office.
  static String _key(String? country, String? state) =>
      '${country?.trim().toLowerCase()}|${state?.trim().toLowerCase()}';

  /// The distinct country+state keys covered by [offices] (those with both
  /// fields populated).
  static Set<String> officeKeys(List<OfficeLocation> offices) => offices
      .where(
        (o) =>
            (o.country?.isNotEmpty ?? false) && (o.state?.isNotEmpty ?? false),
      )
      .map((o) => _key(o.country, o.state))
      .toSet();

  /// Holidays from [rows] that match one of the [officeKeys].
  static List<HolidayRow> matchingHolidays(
    List<HolidayRow> rows,
    Set<String> officeKeys,
  ) =>
      rows.where((r) => officeKeys.contains(_key(r.country, r.state))).toList();

  /// Bounded so a dead network can't leave the Settings "Syncing…" flow (or a
  /// background sync) hanging forever.
  static const _fetchTimeout = Duration(seconds: 15);

  Future<String?> _fetchCsv() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(Uri.parse(csvUrl)).timeout(_fetchTimeout);
      final resp = await req.close().timeout(_fetchTimeout);
      if (resp.statusCode != 200) return null;
      return await resp.transform(utf8.decoder).join().timeout(_fetchTimeout);
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  /// Fetches the CSV and imports matching holidays. Never throws — a failed
  /// sync is a no-op — but the returned [HolidaySyncResult] says why nothing
  /// was added, so a sync that can never succeed does not read as "no new
  /// holidays".
  Future<HolidaySyncResult> sync() async {
    final db = DatabaseService.instance;
    final offices = await db.getOfficeLocations();
    if (offices.isEmpty) {
      return const HolidaySyncResult(0, HolidaySyncOutcome.noOffices);
    }
    final keys = officeKeys(offices);
    if (keys.isEmpty) {
      return const HolidaySyncResult(0, HolidaySyncOutcome.noRegion);
    }

    final csv = await _fetchCsv();
    if (csv == null) {
      return const HolidaySyncResult(0, HolidaySyncOutcome.unavailable);
    }

    final matches = matchingHolidays(parseCsv(csv), keys);
    if (matches.isEmpty) {
      return const HolidaySyncResult(0, HolidaySyncOutcome.unchanged);
    }

    // One query per table instead of two queries per CSV row.
    final dismissed = await db.getDismissedHolidayDates();
    final existingSpecial = await db.getAllSpecialDayDates();
    final attendance = await db.getAllAttendanceDates();

    var inserted = 0;
    for (final h in matches) {
      // Manual edits win, real attendance wins, and a removed holiday stays
      // removed — only fill in untouched days.
      if (dismissed.contains(h.date)) continue;
      if (existingSpecial.contains(h.date)) continue;
      if (attendance.contains(h.date)) continue;

      await db.upsertSpecialDay(
        SpecialDay(
          date: h.date,
          type: DayType.holiday,
          note: h.desc.isEmpty ? null : h.desc,
          source: DaySource.auto,
        ),
      );
      // So a duplicate date later in the CSV is skipped, like it was when the
      // existence check re-queried the database for every row.
      existingSpecial.add(h.date);
      inserted++;
    }
    return HolidaySyncResult(
      inserted,
      inserted > 0 ? HolidaySyncOutcome.added : HolidaySyncOutcome.unchanged,
    );
  }
}

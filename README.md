# Office Attendance Register

A Flutter mobile app that automatically tracks your return-to-office days using GPS geofencing, with full manual override support.

## Features

- **Register your office** — save name, address and detection radius (50–500 m)
- **Auto check-in** — a background task runs every 15 minutes; when you are within range, your attendance is recorded once per day in a local SQLite database. Opening the app while at the office records it too (a safety net for when the OS kills the background task)
- **Permission setup flow** — after the first office is saved, the app walks you through granting background location, notifications and battery-optimisation exemption, with one-tap requests (also available later under Settings → Permissions)
- **Push notification** — you get a notification the moment attendance is recorded
- **Dashboard** — a monthly calendar highlights every recorded day, with monthly and yearly totals and return-to-office percentages
- **Mark a Day** — pick any past date and mark it as Attended, Public Holiday, Sick / Annual / Carer's / Misc Leave or Work from Home, with an optional comment; entries can be edited or removed later
- **Explain page** — itemises exactly how the return-to-office percentage is calculated for a month or a (financial) year
- **Configurable target** — set the RTO percentage your employer expects; dashboard stats turn green at or above it
- **History** — a chronological list of every recorded day
- **Multi-office** — track multiple office locations independently
- **Auto public holidays** — public holidays for your office's region are highlighted automatically from a list published in this repo (see [Public Holidays](#public-holidays)); anything you mark or remove yourself always wins
- **Data export** — copy a CSV of every recorded day to the clipboard as a backup
- **Themes** — colour palettes inspired by Australian birds
- **Edit / delete** — update the radius or remove an office at any time

## Getting Started

### Prerequisites

- Flutter SDK ≥ 3.38.1 (Dart ≥ 3.8) — [install guide](https://docs.flutter.dev/get-started/install)
- Android Studio / Xcode for device/emulator builds

### Clone & run

```bash
git clone https://github.com/ryandam9/attendance-register.git
cd attendance-register

# Generate the platform boilerplate (run once)
flutter create . --project-name attendance_register --org com.example

# Install dependencies
flutter pub get

# Run on a connected device or emulator
flutter run
```

> **Why `flutter create .`?**  
> This repo ships only the hand-written source files. Running `flutter create .` generates the remaining Android/iOS boilerplate (Gradle wrapper, Xcode project, etc.) without overwriting anything that already exists.

---

## Platform Setup

### Android

1. The `AndroidManifest.xml` already declares all required permissions.
2. The app requests location ("Allow all the time"), notifications and battery-optimisation exemption after the first office is saved; the same requests are available under **Settings → Permissions**.
3. If a permission was permanently denied, the app opens the relevant system settings page instead.

### iOS

1. The `Info.plist` already contains location usage strings and `BGTaskSchedulerPermittedIdentifiers`.
2. Grant **"Always"** location when prompted (or via Settings → Office Attendance → Location).
3. WorkManager on iOS uses `BGProcessingTask`; tasks run when the OS decides conditions are met (plugged in, idle). The foreground check on app open/resume compensates for missed background runs.

---

## Architecture

```
lib/
├── main.dart                        # App entry point + WorkManager setup
├── app_colors.dart                  # Semantic colour tokens (calendar dots, chips)
├── models/
│   ├── office_location.dart         # Office data model (value equality)
│   ├── attendance_record.dart       # Attendance record model (includes reason field)
│   ├── special_day.dart             # Leave/holiday/WFH day types + percentage rules
│   ├── attendance_breakdown.dart    # Percentage maths shared by dashboard & Explain
│   └── report_period.dart           # Month / financial-year reporting windows
├── services/
│   ├── database_service.dart        # SQLite CRUD (singleton, schema v7, FKs enforced)
│   ├── location_service.dart        # GPS + background/foreground check logic
│   ├── holiday_service.dart         # Public-holiday CSV import
│   ├── notification_service.dart    # Local notifications
│   ├── permission_service.dart      # Runtime permission requests
│   ├── app_settings_service.dart    # Deep links into system settings pages
│   └── export_service.dart          # CSV backup of all recorded days
├── providers/                       # Riverpod state (Notifier-based)
│   ├── office_provider.dart
│   ├── attendance_provider.dart
│   ├── special_day_provider.dart
│   ├── settings_provider.dart       # FY start, theme, name, RTO target
│   └── explain_provider.dart
├── widgets/
│   └── permission_cards.dart        # Permission status cards w/ grant buttons
├── helpers/
│   ├── day_type_helper.dart         # Labels, icons & colours per day type
│   └── route_helper.dart
├── themes/
│   └── bird_themes.dart             # Australian-bird colour palettes
└── screens/
    ├── home_screen.dart             # Dashboard + calendar
    ├── day_entry_screen.dart        # Pick a day → status + comment
    ├── explain_screen.dart          # Percentage breakdown report
    ├── history_screen.dart          # Chronological list of recorded days
    ├── setup_screen.dart            # Add / edit office
    ├── permission_setup_screen.dart # First-run permission walkthrough
    ├── settings_screen.dart         # Profile, target, offices, permissions, data
    └── theme_screen.dart            # Theme picker
```

## Key Packages

| Package | Purpose |
|---|---|
| `sqflite` | Local SQLite database |
| `geolocator` | GPS positioning |
| `geocoding` | Address ↔ coordinate lookup |
| `workmanager` | 15-minute background task |
| `table_calendar` | Calendar widget |
| `flutter_local_notifications` | Attendance notifications |
| `permission_handler` | Runtime permission requests & status |
| `flutter_riverpod` | State management |

## How the Background Check Works

```
WorkManager (every 15 min)            App open / resume
  └─ callbackDispatcher()               └─ HomeScreen
       └─ LocationService                    └─ LocationService
            .performBackgroundCheck()             .performForegroundCheck()
                 │                                     │
                 └──────────── shared logic ───────────┘
                      ├─ load registered offices from SQLite
                      ├─ skip unless location permission already granted
                      ├─ skip if today is marked as a holiday / leave day
                      ├─ get current GPS position
                      └─ for each office:
                           ├─ skip if attendance already recorded today
                           ├─ calculate distance to office
                           └─ if distance ≤ radius → insert record
                                ├─ background: show notification
                                └─ foreground: show in-app snackbar
```

The foreground check exists because OS battery management (especially on iOS,
and on aggressive Android OEMs) can stop the periodic task; opening the app
while at the office always records the day.

> **Roadmap:** the 15-minute polling approach trades battery for simplicity. A
> future improvement is platform geofencing (Android `GeofencingClient` / iOS
> region monitoring), which is event-driven, more battery-friendly and fires
> even when the app process is dead. It requires native code on both platforms
> and on-device testing, so it is deliberately not bundled with app-level
> changes.

## Percentage Rules

The return-to-office percentage is **weekday-based** on both sides of the
division:

- **Denominator** — weekdays (Mon–Fri) in the period, minus public holidays and
  sick/annual/carer's/misc leave that fall on weekdays.
- **Numerator** — days recorded at the office that fall on weekdays. Weekend
  check-ins still appear on the calendar, in History and in the day totals, but
  they cannot inflate the percentage (the Explain page lists them separately).
- **Work-from-home** days stay in the denominator, so they lower the
  percentage.

The yearly stat follows the reporting year configured on the Explain page —
calendar year (Jan–Dec) or financial year (Oct–Sep).

## Mark a Day

From the dashboard tap **Mark a Day** (or tap any calendar day) to open the
day-entry screen:

1. **Pick a date** — any past date back to 2020.
2. **Pick a status** — Attended, Public Holiday, Sick Leave, Annual Leave,
   Carer's Leave, Work from Home or Misc Leave. Saving one status replaces any
   conflicting entry of another kind.
3. **Comment** — optional note shown in History.
4. **Save / Update / Remove Entry** — the home calendar and stats refresh
   automatically when you return.

## Public Holidays

Public holidays are pre-determined, so the app highlights them for you instead
of making you enter each one by hand.

### How it works

1. A CSV of holidays lives in this repo: [`public-holidays.csv`](public-holidays.csv).
   Each row is `country,state,date,desc`:

   ```csv
   country,state,date,desc
   AU,Western Australia,2026-06-01,Western Australia Day
   US,California,2026-07-04,Independence Day
   ```

   - `country` — ISO country code (e.g. `AU`, `US`)
   - `state` — administrative area exactly as the geocoder reports it for the
     office address (e.g. `Western Australia`, `California`)
   - `date` — `YYYY-MM-DD` (rows with malformed dates are skipped)
   - `desc` — shown as the note on the calendar entry (commas are allowed)

2. When you register an office, the app reverse-geocodes the address and stores
   its **country** and **state** alongside the coordinates.

3. On launch (and via **Settings → Sync Public Holidays Now**) the app fetches
   the CSV from GitHub and, for every holiday whose `country` + `state` matches
   one of your offices, inserts a holiday entry — which the calendar highlights
   and the attendance-percentage maths excludes. Matching is case-insensitive.

To add or correct holidays, edit `public-holidays.csv` on `main`; the change is
picked up on the next sync — no app release required.

### Manual edits always win

Auto-imported holidays never fight with your own entries:

- A holiday is **only** added to a day that has nothing on it — never over a day
  you marked yourself or actually attended.
- If you **remove** an auto-imported holiday, it is remembered and not
  re-added on the next sync.
- Editing an auto holiday (e.g. to Sick Leave) converts it to a manual entry,
  which the importer then leaves alone.

## Data Export

**Settings → Data → Export All Data (CSV)** copies every recorded day —
attendance (with office name), leave, holidays and WFH — to the clipboard as
CSV (`date,status,office,comment`), newest first. Paste it into a file or
spreadsheet to keep a backup outside the device.

## Running Tests

```bash
flutter test
```

Tests cover:
- `AttendanceRecord`, `OfficeLocation` (incl. value equality) and `SpecialDay`
  serialisation
- `AttendanceBreakdown` percentage rules, including weekend exclusion
- `ReportPeriod` month/financial-year windows
- Holiday CSV parsing, including malformed-date rejection
- Database schema: CRUD, duplicate-insert handling, month-range queries,
  multi-office isolation, weekday-only counting, transactional office deletion
- `DayEntryScreen` widget tests: save, replace-on-status-change, remove

The database tests use `sqflite_common_ffi` with an in-memory database so they
run on desktop without a device. CI (GitHub Actions) runs `flutter analyze` and
`flutter test` on every PR.

## Database Schema

**Version 7** (older versions are upgraded automatically on first launch).
Foreign keys are enforced (`PRAGMA foreign_keys = ON`).

```sql
CREATE TABLE office_locations (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  name      TEXT    NOT NULL,
  address   TEXT    NOT NULL,
  latitude  REAL    NOT NULL,
  longitude REAL    NOT NULL,
  radius    REAL    NOT NULL DEFAULT 200.0,
  country   TEXT,            -- ISO code, for public-holiday matching
  state     TEXT             -- administrative area, for public-holiday matching
);

CREATE TABLE attendance_records (
  id                 INTEGER PRIMARY KEY AUTOINCREMENT,
  date               TEXT    NOT NULL,       -- YYYY-MM-DD
  office_location_id INTEGER NOT NULL,
  timestamp          TEXT    NOT NULL,       -- ISO-8601
  reason             TEXT,                   -- nullable, set on manual entries
  FOREIGN KEY (office_location_id) REFERENCES office_locations(id)
);

CREATE UNIQUE INDEX idx_attendance_date
  ON attendance_records(date, office_location_id);

CREATE TABLE special_days (
  id     INTEGER PRIMARY KEY AUTOINCREMENT,
  date   TEXT NOT NULL UNIQUE,               -- YYYY-MM-DD
  type   TEXT NOT NULL,                      -- holiday | sickLeave | annualLeave |
                                             -- carersLeave | workFromHome | miscLeave
  note   TEXT,
  source TEXT NOT NULL DEFAULT 'manual'      -- manual | auto (holiday importer)
);

CREATE TABLE dismissed_holidays (             -- auto-holidays the user removed
  date TEXT PRIMARY KEY
);

CREATE TABLE app_settings (                   -- key/value preferences
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
```

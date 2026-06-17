# Office Attendance Register

A Flutter mobile app that automatically tracks your return-to-office days using GPS geofencing, with full manual override support.

## Features

- **Register your office** — save name, address and detection radius (50–500 m)
- **Auto check-in** — each office is registered as an OS-level geofence; when your phone enters the radius the OS wakes the app (even if it was killed) and attendance is recorded once per day in a local SQLite database. Opening the app while at the office records it too (a safety net for missed geofence events)
- **Permission setup flow** — after the first office is saved, the app walks you through granting background location, notifications and battery-optimisation exemption, with one-tap requests (also available later under Settings → Permissions)
- **Push notification** — you get a notification the moment attendance is recorded
- **Dashboard** — a monthly calendar highlights every recorded day, with animated monthly and yearly totals and return-to-office percentages; bottom navigation switches between Home, Insights and History
- **Quick day marking** — tapping a calendar day opens a bottom sheet with one-tap statuses (Attended, Public Holiday, Sick / Annual / Carer's / Misc Leave, Work from Home) and an optional comment; "All options" opens the full editor
- **Explain page** — itemises exactly how the return-to-office percentage is calculated for a month or a (financial) year
- **Configurable target** — set the RTO percentage your employer expects; dashboard stats turn green at or above it
- **History** — a chronological list of every recorded day
- **Multi-office** — track multiple office locations independently
- **Auto public holidays** — public holidays for your office's region are highlighted automatically from a list published in this repo (see [Public Holidays](#public-holidays)); anything you mark or remove yourself always wins
- **Data export** — copy a CSV of every recorded day to the clipboard as a backup
- **Themes** — colour palettes inspired by Australian birds, Material You dynamic colour ("match my wallpaper", Android 12+), and a light/dark/system toggle
- **Edit / delete** — update the radius or remove an office at any time

## Getting Started

### Download the app (Android)

No build environment needed — CI builds an APK automatically:

- **Latest build:** grab `app-release.apk` from the
  [latest release](https://github.com/ryandam9/attendance-register/releases/latest),
  rebuilt on every push to `main`.
- **Any branch on demand:** Actions tab → **CI** → *Run workflow*, then
  download the `attendance-register-apk` artifact from that run.

The APK is debug-signed (fine for personal sideloading, not store
distribution) and needs Android 8.0+.

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

1. Requires Android 8.0+ (minSdk 26, needed by `native_geofence`) and Google
   Play Services (geofencing is delivered by `GeofencingClient`).
2. The `AndroidManifest.xml` already declares all required permissions and the
   geofencing receivers (including boot re-registration).
3. The app requests location ("Allow all the time"), notifications and battery-optimisation exemption after the first office is saved; the same requests are available under **Settings → Permissions**.
4. If a permission was permanently denied, the app opens the relevant system settings page instead.

### iOS

1. The `Info.plist` already contains the location usage strings; no background
   mode is needed — region monitoring relaunches the app on geofence crossings.
2. Grant **"Always"** location when prompted (or via Settings → Office Attendance → Location).
3. iOS limits an app to 20 monitored regions — far more offices than the app
   will ever register.

---

## Architecture

```
lib/
├── main.dart                        # App entry point, theming + geofencing init
├── app_colors.dart                  # Semantic colour tokens (calendar dots, chips)
├── models/
│   ├── office_location.dart         # Office data model (value equality)
│   ├── attendance_record.dart       # Attendance record model (includes reason field)
│   ├── special_day.dart             # Leave/holiday/WFH day types + percentage rules
│   ├── attendance_breakdown.dart    # Percentage maths shared by dashboard & Explain
│   └── report_period.dart           # Month / financial-year reporting windows
├── services/
│   ├── database_service.dart        # SQLite CRUD (singleton, schema v7, FKs enforced)
│   ├── location_service.dart        # GPS, geofence sync + check-in recording
│   ├── holiday_service.dart         # Public-holiday CSV import
│   ├── notification_service.dart    # Local notifications
│   ├── permission_service.dart      # Runtime permission requests
│   ├── app_settings_service.dart    # Deep links into system settings pages
│   └── export_service.dart          # CSV backup of all recorded days
├── providers/                       # Riverpod state (Notifier-based)
│   ├── office_provider.dart
│   ├── attendance_provider.dart
│   ├── special_day_provider.dart
│   ├── settings_provider.dart       # FY start, theme + mode, name, RTO target
│   ├── ui_state_provider.dart       # Tab index, calendar focus/format
│   └── explain_provider.dart
├── widgets/
│   ├── permission_cards.dart        # Permission status cards w/ grant buttons
│   ├── quick_mark_sheet.dart        # One-tap day-marking bottom sheet
│   └── no_office_placeholder.dart
├── helpers/
│   ├── day_type_helper.dart         # Labels, icons & colours per day type
│   ├── day_marking.dart             # Shared save/remove rules for a day
│   └── route_helper.dart
├── themes/
│   └── bird_themes.dart             # App theme builder + bird palettes
└── screens/
    ├── main_shell.dart              # Bottom navigation + app lifecycle work
    ├── home_screen.dart             # Dashboard + calendar
    ├── day_entry_screen.dart        # Full day editor (status + comment)
    ├── explain_screen.dart          # Insights tab: percentage breakdown
    ├── history_screen.dart          # History tab: every recorded day
    ├── setup_screen.dart            # Add / edit office
    ├── permission_setup_screen.dart # First-run permission walkthrough
    ├── settings_screen.dart         # Profile, target, offices, permissions, data
    └── theme_screen.dart            # Appearance: mode, Material You, birds
```

## Key Packages

| Package | Purpose |
|---|---|
| `sqflite` | Local SQLite database |
| `geolocator` | GPS positioning |
| `geocoding` | Address ↔ coordinate lookup |
| `native_geofence` | OS-level geofencing (auto check-in) |
| `network_info_plus` | Connected Wi-Fi SSID (Wi-Fi check-in) |
| `table_calendar` | Calendar widget |
| `flutter_local_notifications` | Attendance notifications |
| `permission_handler` | Runtime permission requests & status |
| `flutter_riverpod` | State management |
| `animations` | Fade-through tab switches, container transforms |
| `confetti` | Check-in celebration |
| `dynamic_color` | Material You wallpaper theming |

## How Auto Check-In Works

Each registered office is mirrored to an OS-level geofence (Android
`GeofencingClient` via the `native_geofence` plugin; iOS region monitoring).
Geofences are (re-)synced whenever an office is added, edited or deleted, on
every app open/resume, and after the "Always" location permission is granted.
Android re-registers them after a reboot; iOS persists monitored regions
itself.

```
OS geofence ENTER event               App open / resume
(fires even when the app is dead)       └─ HomeScreen
  └─ geofenceTriggered()                     └─ LocationService
       └─ LocationService                         .performForegroundCheck()
            .recordGeofenceCheckIn()                   │ (reads GPS once,
                 │                                     │  same guards)
                 └──────────── shared rules ───────────┘
                      ├─ skip if the office no longer exists
                      ├─ skip if today is marked as a holiday / leave day
                      ├─ skip if attendance already recorded today
                      └─ insert record (once per day per office)
                           ├─ geofence: show notification
                           └─ foreground: show in-app snackbar
```

Being event-driven, this uses near-zero battery compared to periodic GPS
polling and fires even when the app process has been killed. The foreground
check on app open remains as a safety net: if the OS ever misses or suppresses
a geofence event, opening the app while at the office still records the day.

### Wi-Fi check-in (second path)

GPS can be off, denied, or unreliable deep indoors. As a fallback, each office
can list its Wi-Fi networks (SSIDs — e.g. the corporate, guest and WLAN
networks). When the device is connected to any of them, `WifiService` records
the day using the **same guards** as the geofence path (skip holidays/leave,
skip dismissed days, once per day per office). The connected SSID is checked on
every app launch/resume and re-checked every 15 minutes while the app is alive;
once the day is recorded it stops for the rest of the day.

Reading the connected SSID is governed by `network_info_plus` and, on Android,
requires the location permission the app already requests plus location
services switched on. Periodic checks currently run while the app is in the
foreground; extending them to a killed-app background schedule would need a
`WorkManager` task and is a possible follow-up.

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
`flutter test` on every PR, and builds a release APK on every push to `main`
(published to the rolling [latest release](https://github.com/ryandam9/attendance-register/releases/latest))
or on demand via the Actions tab's *Run workflow* button.

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

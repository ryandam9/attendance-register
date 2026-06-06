# Office Attendance Register

A Flutter mobile app that automatically tracks your return-to-office days using GPS geofencing, with full manual override support.

## Features

- **Register your office** — save name, address and detection radius (50–500 m)
- **Auto check-in** — a background task runs every 15 minutes; when you are within range, your attendance is recorded once per day in a local SQLite database
- **Push notification** — you get a notification the moment attendance is recorded
- **Dashboard** — a monthly calendar highlights every day you were in the office, with monthly and yearly totals
- **Manual attendance update** — pick any past date, mark it as present, and optionally enter a reason (e.g. "Missed auto check-in", "Team meeting"); you can also remove a record or update its reason after the fact
- **Multi-office** — track multiple office locations independently
- **Auto public holidays** — public holidays for your office's region are highlighted automatically from a list published in this repo (see [Public Holidays](#public-holidays)); anything you mark or remove yourself always wins
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
2. After installing the app, grant **"Allow all the time"** for location (Settings → Apps → Office Attendance → Permissions → Location).
3. Disable battery optimisation for the app so WorkManager fires reliably (Settings → Battery → Unrestricted).

### iOS

1. The `Info.plist` already contains location usage strings and `BGTaskSchedulerPermittedIdentifiers`.
2. After installing the app, go to Settings → Office Attendance → Location → select **"Always"**.
3. WorkManager on iOS uses `BGProcessingTask`; tasks run when the OS decides conditions are met (plugged in, idle). For more reliable polling on iOS, consider [background_fetch](https://pub.dev/packages/background_fetch) as an alternative.

---

## Architecture

```
lib/
├── main.dart                    # App entry point + WorkManager setup
├── models/
│   ├── office_location.dart     # Office data model
│   └── attendance_record.dart   # Attendance record model (includes reason field)
├── services/
│   ├── database_service.dart    # SQLite CRUD (singleton, schema v2)
│   ├── location_service.dart    # GPS + background check logic
│   └── notification_service.dart
├── providers/
│   ├── office_provider.dart     # ChangeNotifier for offices
│   └── attendance_provider.dart # ChangeNotifier for attendance
└── screens/
    ├── home_screen.dart             # Dashboard + calendar
    ├── day_entry_screen.dart        # Pick a day → Attendance / Holiday / Sick Leave + comment
    ├── setup_screen.dart            # Add / edit office
    └── settings_screen.dart         # Manage offices
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
| `provider` | State management |

## How the Background Check Works

```
WorkManager (every 15 min)
  └─ callbackDispatcher()
       └─ LocationService.performBackgroundCheck()
            ├─ load all registered offices from SQLite
            ├─ get current GPS position
            └─ for each office:
                 ├─ skip if attendance already recorded today
                 ├─ calculate distance to office
                 └─ if distance ≤ radius → insert record + show notification
```

## Manual Attendance Update

From the dashboard tap **Update Attendance** to open the manual screen:

1. **Pick a date** — tap the date field to open a date picker; you can select any past date back to 2020.
2. **Toggle presence** — flip the switch to mark the day as present or absent.
3. **Enter a reason** — an optional text field appears when the day is marked present. Use it to explain why the record was added manually.
4. **Save** — commits the change (insert or update).
5. **Remove Record** — shown when an existing record exists and the toggle is turned off; deletes the record after confirmation.

The home calendar and stats update automatically when you return from the screen.

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
   - `date` — `YYYY-MM-DD`
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

## Running Tests

```bash
flutter test
```

Tests cover:
- `AttendanceRecord` serialisation (`toMap` / `fromMap`) including the `reason` field
- `OfficeLocation` serialisation and `copyWith`
- Database schema: CRUD operations, duplicate-insert handling, month-range queries, multi-office isolation

The database tests use `sqflite_common_ffi` with an in-memory database so they run on desktop without a device.

## Database Schema

**Version 2** (upgraded automatically from v1 on first launch):

```sql
CREATE TABLE office_locations (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  name      TEXT    NOT NULL,
  address   TEXT    NOT NULL,
  latitude  REAL    NOT NULL,
  longitude REAL    NOT NULL,
  radius    REAL    NOT NULL DEFAULT 200.0
);

CREATE TABLE attendance_records (
  id                 INTEGER PRIMARY KEY AUTOINCREMENT,
  date               TEXT    NOT NULL,       -- YYYY-MM-DD
  office_location_id INTEGER NOT NULL,
  timestamp          TEXT    NOT NULL,       -- ISO-8601
  reason             TEXT,                  -- nullable, set on manual entries
  FOREIGN KEY (office_location_id) REFERENCES office_locations(id)
);

CREATE UNIQUE INDEX idx_attendance_date
  ON attendance_records(date, office_location_id);
```

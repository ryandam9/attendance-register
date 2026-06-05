# Office Attendance Register

A Flutter mobile app that automatically tracks your return-to-office days using GPS geofencing.

## Features

- **Register your office** — save name, address and detection radius (50–500 m)
- **Auto check-in** — a background task runs every 15 minutes; when you are within range, your attendance is recorded once per day in a local SQLite database
- **Push notification** — you get a notification the moment attendance is recorded
- **Dashboard** — a monthly calendar highlights every day you were in the office, with monthly and yearly totals
- **Manual check-in** — tap a button to record today manually (useful if you arrive before the 15-minute poll fires)
- **Multi-office** — track multiple office locations independently
- **Edit / delete** — update the radius or remove an office at any time

## Getting Started

### Prerequisites

- Flutter SDK ≥ 3.4.0 — [install guide](https://docs.flutter.dev/get-started/install)
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
│   └── attendance_record.dart   # Attendance record model
├── services/
│   ├── database_service.dart    # SQLite CRUD (singleton)
│   ├── location_service.dart    # GPS + background check logic
│   └── notification_service.dart
├── providers/
│   ├── office_provider.dart     # ChangeNotifier for offices
│   └── attendance_provider.dart # ChangeNotifier for attendance
└── screens/
    ├── home_screen.dart         # Dashboard + calendar
    ├── setup_screen.dart        # Add / edit office
    └── settings_screen.dart     # Manage offices
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

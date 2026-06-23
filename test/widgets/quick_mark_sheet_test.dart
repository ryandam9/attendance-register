import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:attendance_register/models/attendance_record.dart';
import 'package:attendance_register/models/office_location.dart';
import 'package:attendance_register/models/special_day.dart';
import 'package:attendance_register/screens/day_entry_screen.dart';
import 'package:attendance_register/services/database_service.dart';
import 'package:attendance_register/widgets/quick_mark_sheet.dart';

/// Hosts a button that opens the quick-mark sheet, so the sheet's pops have a
/// route to return to.
class _Host extends StatelessWidget {
  final OfficeLocation office;
  final DateTime date;
  const _Host({required this.office, required this.date});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () =>
              showQuickMarkSheet(context, office: office, date: date),
          child: const Text('open'),
        ),
      ),
    );
  }
}

void main() {
  const dateKey = '2026-06-10';
  final date = DateTime(2026, 6, 10);
  final service = DatabaseService.instance;
  late OfficeLocation office;

  setUpAll(() {
    sqfliteFfiInit();
    // The no-isolate factory completes through microtasks, which widget tests'
    // fake-async event loop can drive; the isolate-backed factory would hang.
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  setUp(() async {
    DatabaseService.overridePath = inMemoryDatabasePath;
    await service.reset();
    final id = await service.insertOfficeLocation(
      const OfficeLocation(
        name: 'HQ',
        address: '1 Main St',
        latitude: 0,
        longitude: 0,
      ),
    );
    office = OfficeLocation(
      id: id,
      name: 'HQ',
      address: '1 Main St',
      latitude: 0,
      longitude: 0,
    );
  });

  tearDown(() async {
    await service.reset();
    DatabaseService.overridePath = null;
  });

  Future<void> openSheet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: _Host(office: office, date: date),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('marking a day as Sick Leave from the sheet saves it', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.tap(find.text('Sick Leave'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Sheet closed and the special day was written.
    expect(find.text('Save'), findsNothing);
    final special = await service.getSpecialDayForDate(dateKey);
    expect(special, isNotNull);
    expect(special!.type, DayType.sickLeave);
    expect(await service.getAttendanceForDate(dateKey, office.id!), isNull);
  });

  testWidgets('saving Attended with a comment writes an attendance record', (
    tester,
  ) async {
    await openSheet(tester);

    // Attended is preselected for an unmarked day.
    await tester.enterText(find.byType(TextField), 'Client visit');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final record = await service.getAttendanceForDate(dateKey, office.id!);
    expect(record, isNotNull);
    expect(record!.reason, 'Client visit');
  });

  testWidgets('"All options" escalates to the full day-entry screen', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.tap(find.text('All options…'));
    await tester.pumpAndSettle();

    expect(find.byType(DayEntryScreen), findsOneWidget);
  });

  testWidgets(
    'marking Work from Home removes an auto check-in inserted after the '
    'sheet opened',
    (tester) async {
      await openSheet(tester);

      // Simulate the background geofence isolate recording an auto check-in
      // while the sheet is already open — the sheet's snapshot says the day is
      // unmarked, so saving used to leave this record behind alongside the WFH
      // special day, and History showed both.
      await service.insertAttendanceRecord(
        AttendanceRecord(
          date: dateKey,
          officeLocationId: office.id!,
          timestamp: DateTime(2026, 6, 10, 9),
          reason: 'Auto check-in',
        ),
      );

      await tester.tap(find.text('Work from Home'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(await service.getAttendanceForDate(dateKey, office.id!), isNull);
      final special = await service.getSpecialDayForDate(dateKey);
      expect(special!.type, DayType.workFromHome);
    },
  );

  testWidgets('removing an auto check-in dismisses the day for auto check-in', (
    tester,
  ) async {
    await service.insertAttendanceRecord(
      AttendanceRecord(
        date: dateKey,
        officeLocationId: office.id!,
        timestamp: DateTime(2026, 6, 10, 9),
        reason: 'Auto check-in',
      ),
    );
    await openSheet(tester);

    await tester.tap(find.byTooltip('Remove entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(await service.getAttendanceForDate(dateKey, office.id!), isNull);
    // The geofence/foreground checks consult this flag, so the deleted
    // check-in cannot be silently re-recorded later the same day.
    expect(await service.isAutoCheckInDismissed(dateKey), isTrue);
  });
}

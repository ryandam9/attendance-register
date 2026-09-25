import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:attendance_register/models/attendance_record.dart';
import 'package:attendance_register/models/office_location.dart';
import 'package:attendance_register/models/special_day.dart';
import 'package:attendance_register/screens/day_entry_screen.dart';
import 'package:attendance_register/services/database_service.dart';

/// Hosts the day-entry screen behind a button so Navigator.pop (on save and
/// remove) has a route to return to.
class _Host extends StatelessWidget {
  final OfficeLocation office;
  final DateTime date;
  const _Host({required this.office, required this.date});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DayEntryScreen(office: office, initialDate: date),
            ),
          ),
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

  Future<void> pumpEntryScreen(WidgetTester tester, {DateTime? on}) async {
    // Tall surface so every status option and button is on-screen and tappable.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: _Host(office: office, date: on ?? date),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('saving Attended creates an attendance record with the comment', (
    tester,
  ) async {
    await pumpEntryScreen(tester);

    await tester.enterText(find.byType(TextField), 'Client visit');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // The screen pops on success.
    expect(find.byType(DayEntryScreen), findsNothing);

    final record = await service.getAttendanceForDate(dateKey, office.id!);
    expect(record, isNotNull);
    expect(record!.reason, 'Client visit');
    expect(await service.getSpecialDayForDate(dateKey), isNull);
  });

  testWidgets('switching an attended day to Sick Leave replaces the record', (
    tester,
  ) async {
    await service.insertAttendanceRecord(
      AttendanceRecord(
        date: dateKey,
        officeLocationId: office.id!,
        timestamp: DateTime(2026, 6, 10, 9),
        reason: 'Team meeting',
      ),
    );

    await pumpEntryScreen(tester);

    // The existing entry is loaded: button says Update, comment is pre-filled.
    expect(find.text('Update'), findsOneWidget);
    expect(find.text('Team meeting'), findsOneWidget);

    await tester.tap(find.text('Sick Leave'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();

    expect(find.byType(DayEntryScreen), findsNothing);
    expect(await service.getAttendanceForDate(dateKey, office.id!), isNull);
    final special = await service.getSpecialDayForDate(dateKey);
    expect(special, isNotNull);
    expect(special!.type, DayType.sickLeave);
  });

  testWidgets('Remove Entry deletes the existing record after confirmation', (
    tester,
  ) async {
    await service.insertAttendanceRecord(
      AttendanceRecord(
        date: dateKey,
        officeLocationId: office.id!,
        timestamp: DateTime(2026, 6, 10, 9),
      ),
    );

    await pumpEntryScreen(tester);

    await tester.tap(find.text('Remove Entry'));
    await tester.pumpAndSettle();
    // Confirm in the dialog.
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(find.byType(DayEntryScreen), findsNothing);
    expect(await service.getAttendanceForDate(dateKey, office.id!), isNull);
  });

  testWidgets('a future date is labelled planned and saves its leave', (
    tester,
  ) async {
    final future = DateTime.now().add(const Duration(days: 45));
    final futureKey = DateFormat('yyyy-MM-dd').format(future);
    await pumpEntryScreen(tester, on: future);

    expect(find.text('Planned ahead'), findsOneWidget);

    await tester.tap(find.text('Annual Leave'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final special = await service.getSpecialDayForDate(futureKey);
    expect(special, isNotNull);
    expect(special!.type, DayType.annualLeave);
  });

  testWidgets('the date picker offers future dates', (tester) async {
    await pumpEntryScreen(tester);

    await tester.tap(find.text('June 10, 2026'));
    await tester.pumpAndSettle();

    // A day well past today must be selectable, otherwise leave can only ever
    // be recorded after it has been taken.
    final future = DateTime.now().add(const Duration(days: 365));
    final lastDate = DateTime(DateTime.now().year + 5, 12, 31);
    expect(future.isBefore(lastDate), isTrue);

    // Switch to the text-entry mode so an arbitrary future date can be typed
    // without paging the grid a year forward.
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(
      // Scoped to the picker: the screen behind it has its own comment field.
      find.descendant(
        of: find.byType(InputDatePickerFormField),
        matching: find.byType(TextField),
      ),
      DateFormat('MM/dd/yyyy').format(future),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(
      find.text(DateFormat('MMMM d, yyyy').format(future)),
      findsOneWidget,
    );
    expect(find.text('Planned ahead'), findsOneWidget);
  });
}

import 'dart:async';
import 'package:attendance_register/helpers/day_type_helper.dart';
import 'package:attendance_register/models/attendance_breakdown.dart';
import 'package:attendance_register/providers/explain_provider.dart';
import 'package:attendance_register/providers/ui_state_provider.dart';
import 'package:attendance_register/models/attendance_record.dart';
import 'package:attendance_register/models/office_location.dart';
import 'package:attendance_register/models/special_day.dart';
import 'package:attendance_register/providers/office_provider.dart';
import 'package:attendance_register/providers/settings_provider.dart';
import 'package:attendance_register/screens/day_entry_screen.dart';
import 'package:attendance_register/screens/explain_screen.dart';
import 'package:attendance_register/screens/history_screen.dart';
import 'package:attendance_register/screens/home_screen.dart';
import 'package:attendance_register/screens/permission_setup_screen.dart';
import 'package:attendance_register/screens/setup_screen.dart';
import 'package:attendance_register/screens/settings_screen.dart';
import 'package:attendance_register/screens/theme_screen.dart';
import 'package:attendance_register/services/database_service.dart';
import 'package:attendance_register/themes/app_font.dart';
import 'package:attendance_register/themes/garden_theme.dart';
import 'package:attendance_register/widgets/quick_mark_sheet.dart';
import 'dart:typed_data';

import 'package:attendance_register/widgets/garden_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:table_calendar/table_calendar.dart';

void main() {
  final db = DatabaseService.instance;
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });
  setUp(() async {
    DatabaseService.overridePath = inMemoryDatabasePath;
    await db.reset();
  });
  tearDown(() async {
    await db.reset();
    DatabaseService.overridePath = null;
  });

  for (final switchOffice in [false, true]) {
    testWidgets(
      'Progress never reuses another ${switchOffice ? 'office' : 'month'}',
      (tester) async {
        tester.view.physicalSize = const Size(400, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        for (final name in ['First office', 'Second office']) {
          await db.insertOfficeLocation(
            OfficeLocation(name: name, address: '', latitude: 0, longitude: 0),
          );
        }
        final pending = Completer<AttendanceBreakdown>();
        BreakdownArgs? initial;
        final container = ProviderContainer(
          overrides: [
            breakdownProvider.overrideWith((ref, args) {
              initial ??= args;
              if (args == initial) {
                return Future.value(
                  const AttendanceBreakdown(
                    weekdays: 20,
                    officeDays: 10,
                    specialDayCounts: {},
                    remainingEligibleDays: 10,
                  ),
                );
              }
              return pending.future;
            }),
          ],
        );
        addTearDown(container.dispose);
        await container.read(officeProvider.notifier).load();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: gardenTheme(Brightness.light),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              ),
              home: const HomeScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('50%'), findsOneWidget);
        final gardenState = tester.state(find.byType(GardenArt));
        final headingElement = tester.element(
          find.text('Your month, gently growing.'),
        );
        final todayElement = tester.element(find.text('TODAY'));
        final scrollPosition = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position;
        final offset = scrollPosition.pixels;
        if (switchOffice) {
          container
              .read(officeProvider.notifier)
              .selectOffice(container.read(officeProvider).offices.last);
        } else {
          final now = container.read(calendarFocusProvider);
          tester
              .widget<TableCalendar>(find.byType(TableCalendar))
              .onPageChanged!(DateTime(now.year, now.month - 1));
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('50%'), findsNothing);
        if (!switchOffice) {
          expect(tester.state(find.byType(GardenArt)), same(gardenState));
          expect(
            tester.element(find.text('Your month, gently growing.')),
            same(headingElement),
          );
          expect(tester.element(find.text('TODAY')), same(todayElement));
          expect(scrollPosition.pixels, offset);
          expect(find.textContaining('Loading '), findsOneWidget);
        }
        pending.complete(
          const AttendanceBreakdown(
            weekdays: 20,
            officeDays: 4,
            specialDayCounts: {},
            remainingEligibleDays: 10,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('20%'), findsOneWidget);
        if (!switchOffice) {
          expect(tester.state(find.byType(GardenArt)), same(gardenState));
          expect(tester.element(find.text('TODAY')), same(todayElement));
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'Home scrolls without overflow at 320px and 2x text: $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await db.insertOfficeLocation(
          const OfficeLocation(
            name: 'Melbourne Studio',
            address: '',
            latitude: 0,
            longitude: 0,
          ),
        );
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await container.read(officeProvider.notifier).load();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: gardenTheme(brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                  // The garden sways forever; settle-based tests need it still.
                  disableAnimations: true,
                ),
                child: child!,
              ),
              home: const HomeScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Your month, gently growing.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('Home or leave'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('All symbols'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final brightness in Brightness.values) {
    testWidgets('Day marking fits 320px at 2x text: $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final id = await db.insertOfficeLocation(
        const OfficeLocation(
          name: 'Melbourne Studio',
          address: '',
          latitude: 0,
          longitude: 0,
        ),
      );
      final office = OfficeLocation(
        id: id,
        name: 'Melbourne Studio',
        address: '',
        latitude: 0,
        longitude: 0,
      );
      final day = DateTime(2026, 6, 10); // a Wednesday
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: gardenTheme(brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                // The garden sways forever; settle-based tests need it still.
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: Column(
                  children: [
                    TextButton(
                      onPressed: () => showQuickMarkSheet(
                        context,
                        office: office,
                        date: day,
                      ),
                      child: const Text('sheet'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              DayEntryScreen(office: office, initialDate: day),
                        ),
                      ),
                      child: const Text('editor'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Where did your day take you?'), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('editor'));
      await tester.pumpAndSettle();
      expect(find.text('Mark a day.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Save'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  /// Pumps [screen] at 320px wide with 2x text, after adding an office and,
  /// when [withData] is set, a few recorded days this month.
  Future<void> pumpSmall(
    WidgetTester tester,
    Widget screen,
    Brightness brightness, {
    bool withData = true,
    bool withOffice = true,
    bool checkedInToday = false,
  }) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final id = !withOffice
        ? null
        : await db.insertOfficeLocation(
            const OfficeLocation(
              name: 'Melbourne Studio',
              address: '',
              latitude: 0,
              longitude: 0,
            ),
          );
    if (checkedInToday && id != null) {
      final now = DateTime.now();
      await db.insertAttendanceRecord(
        AttendanceRecord(
          date: DateFormat('yyyy-MM-dd').format(now),
          officeLocationId: id,
          timestamp: DateTime(now.year, now.month, now.day, 9, 4),
        ),
      );
    }
    if (withData && id != null) {
      final now = DateTime.now();
      final key = DateFormat('yyyy-MM-dd');
      await db.insertAttendanceRecord(
        AttendanceRecord(
          date: key.format(DateTime(now.year, now.month, 1)),
          officeLocationId: id,
          timestamp: DateTime(now.year, now.month, 1, 9),
          reason: 'Team workshop with a fairly long note attached',
        ),
      );
      await db.upsertSpecialDay(
        SpecialDay(
          date: key.format(DateTime(now.year, now.month, 2)),
          type: DayType.workFromHome,
        ),
      );
      await db.upsertSpecialDay(
        SpecialDay(
          date: key.format(DateTime(now.year, now.month, 3)),
          type: DayType.annualLeave,
          note: 'A long weekend',
        ),
      );
    }
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(officeProvider.notifier).load();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: gardenTheme(brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              // The garden sways forever; settle-based tests need it still.
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets('Insights fits 320px at 2x text: $brightness', (tester) async {
      await pumpSmall(tester, const ExplainScreen(), brightness);
      expect(find.text('See your rhythm.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Recorded days'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Annual Leave'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('History fits 320px at 2x text: $brightness', (tester) async {
      await pumpSmall(tester, const HistoryScreen(), brightness);
      expect(find.text('Days, remembered.'), findsOneWidget);
      // Each day shows its status as a tag; office days add the time they
      // were recorded on the day.
      await tester.scrollUntilVisible(
        find.text('Annual Leave'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('A long weekend'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('9:00 AM'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      expect(tester.takeException(), isNull);

      // A search with no hits shows the no-match message, not the welcome.
      await tester.scrollUntilVisible(
        find.byType(TextField),
        -150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No matching days'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Empty history fits 320px at 2x text: $brightness', (
      tester,
    ) async {
      await pumpSmall(
        tester,
        const HistoryScreen(),
        brightness,
        withData: false,
      );
      expect(find.text('A fresh beginning.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Open calendar'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets('Settings and its pages fit 320px at 2x text: $brightness', (
      tester,
    ) async {
      await pumpSmall(tester, const SettingsScreen(), brightness);
      expect(find.text('Make yourself at home.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (final (row, heading) in const [
        ('Offices', 'Your offices.'),
        ('Reporting', 'Set your target.'),
        ('Automatic check-in', 'Arrive and settle in.'),
        ('Public holidays', 'Days to step away.'),
        ('Data & privacy', 'Take your days with you.'),
        ('About', 'Room for your workday.'),
      ]) {
        await tester.ensureVisible(find.text(row));
        await tester.pumpAndSettle();
        await tester.tap(find.text(row));
        await tester.pumpAndSettle();
        expect(find.text(heading), findsOneWidget, reason: row);
        // Scroll the page to its end so every section is laid out.
        await tester.fling(
          find.byType(Scrollable).last,
          const Offset(0, -3000),
          3000,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: row);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets('First-run screens fit 320px at 2x text: $brightness', (
      tester,
    ) async {
      // Welcome: Home before any office exists.
      await pumpSmall(
        tester,
        const HomeScreen(),
        brightness,
        withData: false,
        withOffice: false,
      );
      expect(find.text('A little presence. A little growth.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Add your first office'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);

      for (final (screen, heading, last) in const [
        (SetupScreen(), 'Put down roots.', 'Save office'),
        (
          PermissionSetupScreen(),
          'Arrive. We’ll take it from here.',
          'Continue to Home',
        ),
      ]) {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: gardenTheme(brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                  // The garden sways forever; settle-based tests need it still.
                  disableAnimations: true,
                ),
                child: child!,
              ),
              home: screen,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(heading), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text(last),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull, reason: heading);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets('Recorded Today card fits 320px at 2x text: $brightness', (
      tester,
    ) async {
      await pumpSmall(
        tester,
        const HomeScreen(),
        brightness,
        withData: false,
        checkedInToday: true,
      );
      await tester.scrollUntilVisible(
        find.text('At the office'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Recorded'), findsOneWidget);
      expect(find.text('Checked in at 9:04 AM'), findsOneWidget);
      expect(find.textContaining('Melbourne Studio'), findsNothing);
      // The whole card opens today's editor.
      await tester.ensureVisible(find.byTooltip('Edit today'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit today'));
      await tester.pumpAndSettle();
      expect(
        find.text(DateFormat('EEEE, d MMMM').format(DateTime.now())),
        findsOneWidget,
      );
      // On a weekend the only change left is removing the entry.
      if (!isWeekendDay(DateTime.now())) {
        expect(find.text('Update'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('Attended day numbers stay readable in dark mode', (
    tester,
  ) async {
    await pumpSmall(
      tester,
      const HomeScreen(),
      Brightness.dark,
      withData: false,
      checkedInToday: true,
    );
    await tester.scrollUntilVisible(
      find.text('All symbols'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // Today is attended, so its number sits on the light dark-mode green.
    final numbers = tester
        .widgetList<Text>(find.text('${DateTime.now().day}'))
        .where((t) => t.style?.fontWeight == FontWeight.bold)
        .toList();
    expect(numbers, isNotEmpty);
    for (final t in numbers) {
      expect(t.style!.color, isNot(Colors.white));
    }
    await tester.pumpWidget(const SizedBox());
  });

  for (final brightness in Brightness.values) {
    testWidgets('Calendar key counts this month and lists every symbol: '
        '$brightness', (tester) async {
      await pumpSmall(tester, const HomeScreen(), brightness);
      await tester.scrollUntilVisible(
        find.text('All symbols'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      // Only the statuses used this month, each with its count.
      Finder keyItem(String label) => find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == label,
      );
      expect(keyItem('Attended: 1 day'), findsOneWidget);
      expect(keyItem('Work from Home: 1 day'), findsOneWidget);
      expect(keyItem('Annual Leave: 1 day'), findsOneWidget);
      expect(find.text('Sick Leave'), findsNothing);

      await tester.ensureVisible(find.text('All symbols'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All symbols'));
      await tester.pumpAndSettle();
      expect(find.text('Calendar symbols'), findsOneWidget);
      final sheet = find.byType(BottomSheet);
      for (final label in ['Sick Leave', 'Public Holiday', 'Today']) {
        await tester.scrollUntilVisible(
          find.descendant(of: sheet, matching: find.text(label)),
          100,
          scrollable: find.descendant(
            of: sheet,
            matching: find.byType(Scrollable),
          ),
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('Home appears once, with today already filled in', (
    tester,
  ) async {
    final id = await db.insertOfficeLocation(
      const OfficeLocation(
        name: 'Melbourne Studio',
        address: '',
        latitude: 0,
        longitude: 0,
      ),
    );
    final now = DateTime.now();
    await db.insertAttendanceRecord(
      AttendanceRecord(
        date: DateFormat('yyyy-MM-dd').format(now),
        officeLocationId: id,
        timestamp: DateTime(now.year, now.month, now.day, 9, 4),
      ),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: gardenTheme(Brightness.light),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const HomeScreen(),
        ),
      ),
    );
    container.read(officeProvider.notifier).load();
    // Step through loading: the page must never show today as unrecorded,
    // or show the progress card before its numbers.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('Not recorded'), findsNothing, reason: 'frame $i');
      if (find.text('At the office').evaluate().isNotEmpty) {
        expect(find.textContaining('Return to office'), findsOneWidget);
      }
    }
    await tester.pumpAndSettle();
    expect(find.text('At the office'), findsOneWidget);
    expect(find.text('Recorded'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Calendar stays a full month and shows only its own dates', (
    tester,
  ) async {
    await pumpSmall(tester, const HomeScreen(), Brightness.light);
    final page = find.byType(Scrollable).first;
    Future<void> showCalendar() => tester.scrollUntilVisible(
      find.text('All symbols'),
      200,
      scrollable: page,
    );
    final calendar = find.byWidgetPredicate((w) => w is TableCalendar);
    Finder day(int n) =>
        find.descendant(of: calendar, matching: find.text('$n'));
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0).day;

    await showCalendar();
    // Six rows are always drawn, so the next month's "1" would show if
    // neighbouring months' days were visible.
    expect(day(1), findsOneWidget);
    expect(day(lastDay), findsOneWidget);

    // A vertical swipe used to shrink the calendar to two weeks or one week.
    await tester.ensureVisible(day(15));
    await tester.pumpAndSettle();
    await tester.fling(day(15), const Offset(0, -300), 1000);
    await tester.pumpAndSettle();
    await showCalendar();
    expect(day(1), findsOneWidget);
    expect(day(lastDay), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  for (final font in AppFont.values) {
    testWidgets('Home fits 320px at 2x text in ${font.label}', (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await db.insertOfficeLocation(
        const OfficeLocation(
          name: 'Melbourne Studio',
          address: '',
          latitude: 0,
          longitude: 0,
        ),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(officeProvider.notifier).load();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: gardenTheme(Brightness.light, font),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                // The garden sways forever; settle-based tests need it still.
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('All symbols'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('Garden flowers sway, and hold still for reduced motion', (
    tester,
  ) async {
    Future<Uint8List> frame() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.descendant(
          of: find.byType(GardenArt),
          matching: find.byType(RepaintBoundary),
        ),
      );
      final image = await tester.runAsync(() => boundary.toImage());
      final bytes = await tester.runAsync(() => image!.toByteData());
      return bytes!.buffer.asUint8List();
    }

    Future<void> pumpGarden({required bool reduceMotion}) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: gardenTheme(Brightness.light),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reduceMotion),
            child: child!,
          ),
          home: const Scaffold(body: GardenArt()),
        ),
      );
    }

    await pumpGarden(reduceMotion: false);
    final first = await frame();
    await tester.pump(const Duration(milliseconds: 1500));
    expect(await frame(), isNot(equals(first)));

    await pumpGarden(reduceMotion: true);
    await tester.pump();
    final still = await frame();
    await tester.pump(const Duration(milliseconds: 1500));
    expect(await frame(), equals(still));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Settings rows and Insights periods animate between pages', (
    tester,
  ) async {
    Future<void> pumpAnimated(Widget screen) async {
      await db.insertOfficeLocation(
        const OfficeLocation(
          name: 'Melbourne Studio',
          address: '',
          latitude: 0,
          longitude: 0,
        ),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(officeProvider.notifier).load();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: gardenTheme(Brightness.light),
            home: screen,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // Container transform: the row opens its page and closes back into it.
    await pumpAnimated(const SettingsScreen());
    await tester.tap(find.text('Reporting'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.text('Set your target.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Make yourself at home.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Shared axis: stepping to the previous month swaps the period content.
    await tester.pumpWidget(const SizedBox());
    await db.reset();
    await pumpAnimated(const ExplainScreen());
    final now = DateTime.now();
    final previous = DateFormat(
      'MMMM yyyy',
    ).format(DateTime(now.year, now.month - 1));
    await tester.tap(find.byTooltip('Previous'));
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.text(previous), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Insights and History mark today from the title bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await db.insertOfficeLocation(
      const OfficeLocation(
        name: 'Melbourne Studio',
        address: '',
        latitude: 0,
        longitude: 0,
      ),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(officeProvider.notifier).load();
    final today = DateFormat('EEEE, d MMMM').format(DateTime.now());

    for (final screen in const [ExplainScreen(), HistoryScreen()]) {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: gardenTheme(Brightness.light),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: screen,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final action = find.descendant(
        of: find.byType(AppBar),
        matching: find.byTooltip('Mark today'),
      );
      expect(action, findsOneWidget);
      await tester.tap(action);
      await tester.pumpAndSettle();
      // An empty weekend can't be marked, so it explains that instead.
      expect(
        isWeekendDay(DateTime.now())
            ? find.text(weekendNotMarkableMessage)
            : find.textContaining(today),
        findsWidgets,
      );
      await tester.tapAt(const Offset(200, 20));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('Appearance preserves theme mode and hides legacy palettes', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: gardenTheme(Brightness.light),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const ThemeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Dark'));
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).themeMode, ThemeMode.dark);

    // Every bundled font is offered, and choosing one is saved.
    await tester.ensureVisible(find.text('Nunito'));
    await tester.tap(find.text('Nunito'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).font, AppFont.nunito);
    expect(find.text('Figtree (default)'), findsOneWidget);
    expect(find.text('Match my wallpaper'), findsNothing);
    expect(find.text('Rainbow Bee-eater'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}

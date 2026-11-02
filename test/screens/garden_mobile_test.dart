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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
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
          find.text('Check in at the office'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('Calendar legend'),
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
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
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
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
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
      await tester.scrollUntilVisible(
        find.textContaining('· Annual Leave'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('A long weekend'), findsOneWidget);
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
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
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
      expect(find.text('Melbourne Studio · 9:04 AM'), findsOneWidget);
      expect(find.text('Edit today'), findsOneWidget);
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
      find.text('Calendar legend'),
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
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Calendar legend'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

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

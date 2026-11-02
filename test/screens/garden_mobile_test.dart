import 'package:attendance_register/models/office_location.dart';
import 'package:attendance_register/providers/office_provider.dart';
import 'package:attendance_register/providers/settings_provider.dart';
import 'package:attendance_register/screens/home_screen.dart';
import 'package:attendance_register/screens/theme_screen.dart';
import 'package:attendance_register/services/database_service.dart';
import 'package:attendance_register/themes/garden_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
    expect(find.text('Match my wallpaper'), findsNothing);
    expect(find.text('Rainbow Bee-eater'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}

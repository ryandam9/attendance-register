import 'package:attendance_register/helpers/route_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  testWidgets('opens secondary tasks in a dialog on macOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await _pumpLauncher(tester);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Secondary task'), findsOneWidget);
  });

  testWidgets('pushes secondary tasks as pages on Android', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await _pumpLauncher(tester);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Secondary task'), findsOneWidget);
  });
}

Future<void> _pumpLauncher(WidgetTester tester) {
  return tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => openAdaptivePage<void>(
                context,
                const Scaffold(body: Text('Secondary task')),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
}

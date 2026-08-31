import 'package:attendance_register/helpers/layout.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<(bool, bool, bool)> layoutAt(WidgetTester tester, double width) async {
    late (bool, bool, bool) result;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: Size(width, 800)),
        child: Builder(
          builder: (context) {
            result = (
              isMediumWidth(context),
              isDesktopWidth(context),
              isExpandedDesktopWidth(context),
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return result;
  }

  testWidgets('phone width uses compact layout', (tester) async {
    expect(await layoutAt(tester, 599), (false, false, false));
  });

  testWidgets('tablet width uses medium layout', (tester) async {
    expect(await layoutAt(tester, 840), (true, false, false));
  });

  testWidgets('compact desktop does not extend the sidebar', (tester) async {
    expect(await layoutAt(tester, 1024), (false, true, false));
  });

  testWidgets('wide desktop can extend the sidebar', (tester) async {
    expect(await layoutAt(tester, 1180), (false, true, true));
  });
}

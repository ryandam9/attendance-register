import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_register/services/notification_service.dart';

void main() {
  group('attendance notification content', () {
    test('keeps the collapsed message concise and includes the office', () {
      final content = buildAttendanceNotificationContent(
        name: 'Ravi',
        officeName: 'Melbourne Office',
        timestamp: DateTime(2026, 6, 19, 7, 25),
      );

      expect(content.title, 'Checked in, Ravi');
      expect(content.body, 'Melbourne Office · 7:25 AM');
      expect(
        content.expandedBody,
        'Your attendance at Melbourne Office was recorded.\n'
        'Fri, 19 Jun 2026 · 7:25 AM',
      );
    });

    test(
      'uses neutral copy and an office fallback when settings are empty',
      () {
        final content = buildAttendanceNotificationContent(
          name: 'there',
          officeName: '  ',
          timestamp: DateTime(2026, 6, 19, 7, 25),
        );

        expect(content.title, 'You’re checked in');
        expect(content.body, 'Office · 7:25 AM');
      },
    );
  });
}

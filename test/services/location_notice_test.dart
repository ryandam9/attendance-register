import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:attendance_register/services/database_service.dart';
import 'package:attendance_register/services/location_service.dart';

/// The "location access is off" notice is persisted, not per-session: turning
/// Location Services on can be out of the user's hands (a managed machine, no
/// admin rights), so the app says it once and then stays quiet.
void main() {
  final service = DatabaseService.instance;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  setUp(() async {
    DatabaseService.overridePath = inMemoryDatabasePath;
    await service.reset();
  });

  tearDown(() async {
    await service.reset();
    DatabaseService.overridePath = null;
  });

  group('location denied notice', () {
    test('is owed until shown, then never again', () async {
      expect(await LocationService.shouldShowDeniedNotice(), isTrue);

      await LocationService.markDeniedNoticeShown();
      expect(await LocationService.shouldShowDeniedNotice(), isFalse);

      // Surviving a restart is the whole point — a session-only flag would
      // show the notice again on every launch.
      expect(await LocationService.shouldShowDeniedNotice(), isFalse);
    });

    test('is owed again once access has been granted', () async {
      await LocationService.markDeniedNoticeShown();

      // performForegroundCheck clears the record whenever permission is held,
      // so access lost later is still reported — once.
      await LocationService.resetDeniedNotice();
      expect(await LocationService.shouldShowDeniedNotice(), isTrue);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_register/models/office_location.dart';
import 'package:attendance_register/services/wifi_service.dart';

void main() {
  group('WifiService.normalizeSsid', () {
    test('strips the quotes Android wraps the SSID in', () {
      expect(WifiService.normalizeSsid('"Office-WiFi"'), 'Office-WiFi');
    });

    test('trims surrounding whitespace', () {
      expect(WifiService.normalizeSsid('  Office  '), 'Office');
    });

    test('returns null for sentinels and empty values', () {
      expect(WifiService.normalizeSsid(null), isNull);
      expect(WifiService.normalizeSsid(''), isNull);
      expect(WifiService.normalizeSsid('""'), isNull);
      expect(WifiService.normalizeSsid('<unknown ssid>'), isNull);
      expect(WifiService.normalizeSsid('0x'), isNull);
    });
  });

  group('WifiService.matchOffice', () {
    const hq = OfficeLocation(
      id: 1,
      name: 'HQ',
      address: '1 Main St',
      latitude: 0,
      longitude: 0,
      wifiNames: ['Office-WiFi', 'Office-Guest'],
    );
    const branch = OfficeLocation(
      id: 2,
      name: 'Branch',
      address: '2 Side St',
      latitude: 0,
      longitude: 0,
      wifiNames: ['Branch-WLAN'],
    );

    test('matches an SSID case-insensitively', () {
      expect(WifiService.matchOffice('office-guest', [hq, branch]), hq);
      expect(WifiService.matchOffice('BRANCH-WLAN', [hq, branch]), branch);
    });

    test('returns null when nothing matches', () {
      expect(WifiService.matchOffice('Cafe-Free', [hq, branch]), isNull);
    });

    test('returns null for a null SSID', () {
      expect(WifiService.matchOffice(null, [hq, branch]), isNull);
    });

    test('ignores offices with no configured networks', () {
      const noWifi = OfficeLocation(
        name: 'Remote',
        address: 'nowhere',
        latitude: 0,
        longitude: 0,
      );
      expect(WifiService.matchOffice('anything', [noWifi]), isNull);
    });
  });
}

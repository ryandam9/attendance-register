import 'package:attendance_register/services/http_geocoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseForward', () {
    test('parses coordinates from a Nominatim /search response', () {
      const body = '''
      [
        {"lat": "-37.8136", "lon": "144.9631", "display_name": "Melbourne"},
        {"lat": "51.5074", "lon": "-0.1278", "display_name": "London"}
      ]''';
      final coords = HttpGeocoder.parseForward(body);
      expect(coords, isNotNull);
      expect(coords!.length, 2);
      expect(coords.first.latitude, closeTo(-37.8136, 1e-6));
      expect(coords.first.longitude, closeTo(144.9631, 1e-6));
    });

    test('returns null for an empty result list', () {
      expect(HttpGeocoder.parseForward('[]'), isNull);
    });

    test('skips entries with unparseable coordinates', () {
      const body =
          '[{"lat": "abc", "lon": "1.0"}, {"lat": "2.0", "lon": "3.0"}]';
      final coords = HttpGeocoder.parseForward(body);
      expect(coords!.length, 1);
      expect(coords.first.latitude, 2.0);
    });
  });

  group('parseReverse', () {
    test('extracts address, state and uppercased country code', () {
      const body = '''
      {
        "display_name": "120 Spencer St, Melbourne VIC 3000, Australia",
        "address": {
          "road": "Spencer Street",
          "state": "Victoria",
          "country_code": "au"
        }
      }''';
      final place = HttpGeocoder.parseReverse(body);
      expect(place, isNotNull);
      expect(place!.address, contains('Spencer St'));
      expect(place.state, 'Victoria');
      expect(place.country, 'AU');
    });

    test('falls back through province/region/county for the state', () {
      const body =
          '{"display_name": "x", "address": {"county": "Fingal", "country_code": "ie"}}';
      final place = HttpGeocoder.parseReverse(body);
      expect(place!.state, 'Fingal');
      expect(place.country, 'IE');
    });

    test('returns null when nothing useful is present', () {
      expect(HttpGeocoder.parseReverse('{}'), isNull);
      expect(HttpGeocoder.parseReverse('{"address": {}}'), isNull);
    });
  });
}

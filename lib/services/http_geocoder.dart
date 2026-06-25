import 'dart:convert';

import 'package:http/http.dart' as http;

/// A latitude/longitude pair returned by a forward geocode.
class GeoCoord {
  final double latitude;
  final double longitude;
  const GeoCoord(this.latitude, this.longitude);
}

/// The structured result of a reverse geocode: a display [address] plus the
/// [state] (administrative area) and [country] (ISO code) used to match an
/// office against the bundled public-holidays list.
typedef GeoPlaceData = ({String? address, String? state, String? country});

/// An HTTP geocoder backed by OpenStreetMap's Nominatim service, used as a
/// fallback on desktop platforms (macOS/Linux/Windows) where the `geocoding`
/// plugin has no native implementation and silently returns nothing.
///
/// Nominatim's usage policy asks for a descriptive User-Agent and a low request
/// rate; this is only hit on explicit user actions during office setup (tapping
/// "look up address" / "use current location"), so the volume is negligible.
class HttpGeocoder {
  HttpGeocoder({http.Client? client, Uri? base})
    : _client = client ?? http.Client(),
      _base = base ?? Uri.parse('https://nominatim.openstreetmap.org');

  final http.Client _client;
  final Uri _base;

  static const Map<String, String> _headers = {
    // Nominatim rejects requests without a real User-Agent identifying the app.
    'User-Agent':
        'attendance-register/1.0 (+https://github.com/ryandam9/attendance-register)',
    'Accept': 'application/json',
  };

  /// Forward geocode: free-text [address] → coordinates (best match first).
  /// Returns null on any network/parse error so callers can degrade quietly.
  Future<List<GeoCoord>?> forward(String address) async {
    final query = address.trim();
    if (query.isEmpty) return null;
    final uri = _base.replace(
      path: '${_base.path}/search',
      queryParameters: {'q': query, 'format': 'jsonv2', 'limit': '5'},
    );
    try {
      final resp = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return null;
      return parseForward(resp.body);
    } catch (_) {
      return null;
    }
  }

  /// Reverse geocode: coordinates → display address + state/country.
  Future<GeoPlaceData?> reverse(double lat, double lng) async {
    final uri = _base.replace(
      path: '${_base.path}/reverse',
      queryParameters: {
        'lat': '$lat',
        'lon': '$lng',
        'format': 'jsonv2',
        'zoom': '18',
        'addressdetails': '1',
      },
    );
    try {
      final resp = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return null;
      return parseReverse(resp.body);
    } catch (_) {
      return null;
    }
  }

  /// Parses a Nominatim `/search` response body into coordinates. Public and
  /// pure so it can be unit-tested without a network round-trip.
  static List<GeoCoord>? parseForward(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! List) return null;
    final out = <GeoCoord>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final lat = double.tryParse('${item['lat']}');
      final lon = double.tryParse('${item['lon']}');
      if (lat != null && lon != null) out.add(GeoCoord(lat, lon));
    }
    return out.isEmpty ? null : out;
  }

  /// Parses a Nominatim `/reverse` response body into a [GeoPlaceData]. Public
  /// and pure so it can be unit-tested without a network round-trip.
  static GeoPlaceData? parseReverse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) return null;
    final display = (decoded['display_name'] as String?)?.trim();
    final address = decoded['address'];
    String? state;
    String? country;
    if (address is Map) {
      // Nominatim nests the administrative area under one of several keys
      // depending on the country; take the first that's present.
      for (final key in ['state', 'province', 'region', 'county']) {
        final v = address[key];
        if (v is String && v.isNotEmpty) {
          state = v;
          break;
        }
      }
      final code = address['country_code'];
      if (code is String && code.isNotEmpty) country = code.toUpperCase();
    }
    final hasAnything =
        (display != null && display.isNotEmpty) ||
        state != null ||
        country != null;
    if (!hasAnything) return null;
    return (
      address: (display == null || display.isEmpty) ? null : display,
      state: state,
      country: country,
    );
  }
}

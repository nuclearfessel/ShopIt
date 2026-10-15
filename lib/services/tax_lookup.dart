import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// A failure with a message that is safe to show the user.
class LookupException implements Exception {
  LookupException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Where the device is, as a place name and country.
class PlaceInfo {
  const PlaceInfo({required this.label, this.countryCode});

  /// e.g. "Irvine, California".
  final String label;

  /// Lower-case ISO 3166-1 alpha-2 code ("us"), when known.
  final String? countryCode;

  bool get isUs => countryCode == 'us';
}

// ---- Location ------------------------------------------------------------

/// Reads the device position once, asking for permission if needed. Works on
/// Android and Windows (Windows needs "Location" turned on in Privacy settings).
Future<Position> currentPosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw LookupException(
        'Location services are turned off. Turn them on in your system '
        'settings and try again.');
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw LookupException(
        'Location permission was not granted. You can allow it in your '
        'system settings, or enter the tax rate by hand.');
  }
  try {
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 20),
      ),
    );
  } on Exception {
    throw LookupException('Could not get your location. Try again, or enter '
        'the tax rate by hand.');
  }
}

// ---- Place name (OpenStreetMap Nominatim) --------------------------------

/// Builds a label like "Irvine, California" from a Nominatim reverse-geocode
/// response (`format=jsonv2&addressdetails=1`). Returns null if it has no
/// usable address.
PlaceInfo? parseNominatim(Map<String, dynamic> json) {
  final a = json['address'];
  if (a is! Map) return null;
  String? pick(List<String> keys) {
    for (final k in keys) {
      final v = a[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  final town = pick(
      ['city', 'town', 'village', 'municipality', 'hamlet', 'suburb', 'county']);
  final region = pick(['state', 'province', 'region', 'state_district']);
  final country = pick(['country']);
  final parts = [town, region ?? (town == null ? null : country)]
      .whereType<String>()
      .toList();
  if (parts.isEmpty && country != null) parts.add(country);
  if (parts.isEmpty) return null;
  final code = a['country_code'];
  return PlaceInfo(
    label: parts.join(', '),
    countryCode: code is String ? code.toLowerCase() : null,
  );
}

/// Names the place at [lat],[lng]. Sends the coordinates to OpenStreetMap's
/// Nominatim service (no account needed).
Future<PlaceInfo?> reversePlace(double lat, double lng,
    {http.Client? client}) async {
  final c = client ?? http.Client();
  try {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'format': 'jsonv2',
      'lat': lat.toStringAsFixed(5),
      'lon': lng.toStringAsFixed(5),
      'zoom': '10',
      'addressdetails': '1',
    });
    // Nominatim's usage policy requires an identifying User-Agent.
    final res = await c
        .get(uri, headers: {'User-Agent': 'Shop-it/1.0 (personal shopping list)'})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return null;
    return parseNominatim(jsonDecode(res.body) as Map<String, dynamic>);
  } on Exception {
    return null; // the place name is optional; the user can type one
  } finally {
    if (client == null) c.close();
  }
}

// ---- US sales tax rate (Ziptax) ------------------------------------------

/// Extracts the combined sales tax as a percent (7.75 for 7.75%) from a Ziptax
/// v60 response, or throws a [LookupException] describing what went wrong.
///
/// Ziptax returns `taxSummaries[0].rate` as a fraction (0.0775). Anything above
/// 1 is treated as already being a percent.
double parseZiptaxPercent(Map<String, dynamic> json) {
  final response = (json['metadata'] as Map?)?['response'] as Map?;
  final code = response?['code'];
  if (code != 100) {
    throw LookupException(switch (code) {
      101 => 'Ziptax did not accept the API key. Check it and try again.',
      107 || 112 => 'Your Ziptax plan does not include this lookup.',
      108 => 'Too many Ziptax requests this minute. Wait a moment and retry.',
      109 || 110 => 'Ziptax could not find a US tax rate for this location.',
      _ => 'Ziptax could not return a rate (code ${code ?? 'unknown'}).',
    });
  }
  final summaries = json['taxSummaries'];
  if (summaries is List && summaries.isNotEmpty) {
    final rate = (summaries.first as Map)['rate'];
    if (rate is num) {
      final r = rate.toDouble();
      final percent = r > 1 ? r : r * 100;
      return double.parse(percent.toStringAsFixed(4));
    }
  }
  throw LookupException('Ziptax returned no rate for this location.');
}

/// Looks up the combined US sales tax percent at [lat],[lng]. Sends the
/// coordinates and the user's own API key to Ziptax. The free plan allows 100
/// lookups a month.
Future<double> ziptaxPercent(double lat, double lng, String apiKey,
    {http.Client? client}) async {
  final c = client ?? http.Client();
  try {
    final uri = Uri.https('api.zip-tax.com', '/request/v60', {
      'lat': lat.toStringAsFixed(5),
      'lng': lng.toStringAsFixed(5),
    });
    final res = await c
        .get(uri, headers: {'X-API-KEY': apiKey})
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body);
    if (body is! Map<String, dynamic>) {
      throw LookupException('Ziptax returned an unexpected response.');
    }
    return parseZiptaxPercent(body);
  } on LookupException {
    rethrow;
  } on Exception {
    throw LookupException(
        'Could not reach Ziptax. Check your connection and try again.');
  } finally {
    if (client == null) c.close();
  }
}

// ---- Settings ------------------------------------------------------------

const _ziptaxKeyPref = 'ziptax_api_key';

/// The user's own Ziptax API key, stored on this device only.
Future<String?> loadZiptaxKey() async {
  final k = (await SharedPreferences.getInstance()).getString(_ziptaxKeyPref);
  return (k == null || k.trim().isEmpty) ? null : k.trim();
}

Future<void> saveZiptaxKey(String? key) async {
  final prefs = await SharedPreferences.getInstance();
  if (key == null || key.trim().isEmpty) {
    await prefs.remove(_ziptaxKeyPref);
  } else {
    await prefs.setString(_ziptaxKeyPref, key.trim());
  }
}

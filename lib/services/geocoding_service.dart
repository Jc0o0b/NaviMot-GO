import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodingResult {
  final String displayName;
  final String shortName;
  final double lat;
  final double lon;

  GeocodingResult({
    required this.displayName,
    required this.shortName,
    required this.lat,
    required this.lon,
  });
}

class GeocodingService {
  static final GeocodingService _instance = GeocodingService._();
  static GeocodingService get shared => _instance;
  GeocodingService._();

  final http.Client _client = http.Client();

  Future<List<GeocodingResult>> search(String query, {int limit = 6}) async {
    if (query.length < 3) return [];
    try {
      final uri = Uri.parse('https://photon.komoot.io/api/?q=${Uri.encodeComponent(query)}&limit=$limit');
      final response = await _client.get(uri);
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final features = data['features'] as List? ?? [];
      final results = <GeocodingResult>[];
      for (final f in features) {
        final fMap = f as Map<String, dynamic>;
        final props = fMap['properties'] as Map<String, dynamic>? ?? {};
        final geometry = fMap['geometry'] as Map<String, dynamic>? ?? {};
        final coords = geometry['coordinates'] as List? ?? [];
        if (coords.length < 2) continue;
        results.add(GeocodingResult(
          displayName: _buildDisplayName(props),
          shortName: _buildShortName(props),
          lat: (coords[1] as num).toDouble(),
          lon: (coords[0] as num).toDouble(),
        ));
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  String _buildShortName(Map<String, dynamic> props) {
    final name = props['name'];
    if (name is String && name.isNotEmpty) return name;
    final street = props['street'];
    final housenumber = props['housenumber'];
    if (street is String && street.isNotEmpty) {
      return housenumber is String && housenumber.isNotEmpty ? '$street $housenumber' : street;
    }
    final city = props['city'];
    if (city is String && city.isNotEmpty) return city;
    final country = props['country'];
    if (country is String && country.isNotEmpty) return country;
    return 'Miejsce bez nazwy';
  }

  String _buildDisplayName(Map<String, dynamic> props) {
    final parts = <String>[_buildShortName(props)];
    for (final key in ['street', 'housenumber', 'postcode', 'city', 'state', 'country']) {
      final v = props[key];
      if (v is String && v.isNotEmpty && !parts.contains(v)) parts.add(v);
    }
    final seen = <String>{};
    final unique = <String>[];
    for (final p in parts) {
      if (seen.add(p)) unique.add(p);
    }
    return unique.join(', ');
  }

  void dispose() => _client.close();
}

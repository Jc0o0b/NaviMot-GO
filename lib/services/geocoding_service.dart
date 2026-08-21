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

  String? lastError;

  Future<List<GeocodingResult>> search(String query, {int limit = 6}) async {
    if (query.length < 3) return [];
    lastError = null;

    var results = await _searchPhoton(query, limit);
    if (results != null) return results;

    results = await _searchNominatim(query, limit);
    if (results != null) return results;

    return [];
  }

  Future<List<GeocodingResult>?> _searchPhoton(
      String query, int limit) async {
    try {
      final uri = Uri.parse(
          'https://photon.komoot.io/api/?q=${Uri.encodeComponent(query)}&limit=$limit');
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) {
        lastError = 'Photon HTTP ${response.statusCode}';
        return null;
      }
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
      if (results.isNotEmpty) {
        lastError = null;
        return results;
      }
      lastError = null;
      return results;
    } catch (e) {
      lastError = 'Photon: $e';
      return null;
    }
  }

  Future<List<GeocodingResult>?> _searchNominatim(
      String query, int limit) async {
    try {
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=$limit&accept-language=pl');
      final response = await _client
          .get(uri, headers: {'User-Agent': 'NaviMotGO/1.1'})
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) {
        lastError = 'Nominatim HTTP ${response.statusCode}';
        return null;
      }
      final data = jsonDecode(response.body) as List;
      final results = <GeocodingResult>[];
      for (final item in data) {
        final m = item as Map<String, dynamic>;
        final lat = double.tryParse(m['lat']?.toString() ?? '');
        final lon = double.tryParse(m['lon']?.toString() ?? '');
        if (lat == null || lon == null) continue;
        final displayName = m['display_name'] as String? ?? '';
        final name = m['name'] as String? ?? '';
        results.add(GeocodingResult(
          displayName: displayName.isNotEmpty ? displayName : name,
          shortName: name.isNotEmpty ? name : displayName,
          lat: lat,
          lon: lon,
        ));
      }
      if (results.isNotEmpty) {
        lastError = null;
        return results;
      }
      lastError = null;
      return results;
    } catch (e) {
      lastError = 'Nominatim: $e';
      return null;
    }
  }

  String _buildShortName(Map<String, dynamic> props) {
    final name = props['name'];
    if (name is String && name.isNotEmpty) return name;
    final street = props['street'];
    final housenumber = props['housenumber'];
    if (street is String && street.isNotEmpty) {
      return housenumber is String && housenumber.isNotEmpty
          ? '$street $housenumber'
          : street;
    }
    final city = props['city'];
    if (city is String && city.isNotEmpty) return city;
    final country = props['country'];
    if (country is String && country.isNotEmpty) return country;
    return 'Miejsce bez nazwy';
  }

  String _buildDisplayName(Map<String, dynamic> props) {
    final parts = <String>[_buildShortName(props)];
    for (final key in [
      'street',
      'housenumber',
      'postcode',
      'city',
      'state',
      'country'
    ]) {
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

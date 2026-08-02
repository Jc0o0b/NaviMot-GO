import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/point_of_interest.dart';
import '../utils/route_scaling.dart';

class POIService {
  static final POIService _instance = POIService._();
  static POIService get shared => _instance;
  POIService._();

  static const List<String> _endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
  ];
  final http.Client _client = http.Client();

  Future<List<PointOfInterest>> fetchPOIsAlongRoute(List<LatLng> waypoints, {double radius = 10000}) async {
    if (waypoints.isEmpty) return [];
    final samples = _samplePoints(waypoints, 4);
    final query = _buildOverpassQuery(samples, radius: radius);
    final pois = await _fetchOverpass(query);
    return _selectBest(pois, waypoints, markerCountForRoute(waypoints));
  }

  Future<List<PointOfInterest>> fetchPOIsNearLocation(LatLng coordinate, {double radius = 10000, POICategory? category}) async {
    final query = _buildOverpassQuery([coordinate], radius: radius, category: category);
    return _fetchOverpass(query);
  }

  Future<List<PointOfInterest>> _fetchOverpass(String query) async {
    Object? lastError;
    for (final ep in _endpoints) {
      try {
        final response = await _client
            .post(Uri.parse(ep), body: {'data': query})
            .timeout(const Duration(seconds: 25));
        if (response.statusCode != 200) continue;
        final body = response.body.trim();
        if (!body.startsWith('{') && !body.startsWith('[')) {
          if (body.contains('Error')) lastError = Exception('Overpass: $ep');
          continue;
        }
        final json = jsonDecode(body);
        if (json is! Map<String, dynamic>) continue;
        final elements = json['elements'] as List? ?? [];
        return _parseElements(elements);
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception('Overpass endpoints niedostępne');
  }

  String _buildOverpassQuery(List<LatLng> samples, {double radius = 10000, POICategory? category}) {
    final categories = category != null ? [category] : POICategory.values;
    final filters = <String>{};
    for (final s in samples) {
      final around = '(around:$radius,${s.latitude.toStringAsFixed(5)},${s.longitude.toStringAsFixed(5)});';
      for (final cat in categories) {
        switch (cat) {
          case POICategory.viewpoint:
            filters.add('node["tourism"="viewpoint"]["name"]$around');
            filters.add('way["tourism"="viewpoint"]["name"]$around');
          case POICategory.mountainPass:
            filters.add('node["mountain_pass"="yes"]["name"]$around');
            filters.add('way["mountain_pass"="yes"]["name"]$around');
            filters.add('node["natural"="mountain_pass"]["name"]$around');
            filters.add('way["natural"="mountain_pass"]["name"]$around');
          case POICategory.scenicRoad:
            filters.add('way["tourism"="scenic_route"]["name"]$around');
          case POICategory.fuel:
            filters.add('node["amenity"="fuel"]["name"]$around');
          case POICategory.service:
            filters.add('node["shop"="motorcycle_repair"]["name"]$around');
            filters.add('node["craft"="motorcycle_repair"]["name"]$around');
            filters.add('way["shop"="motorcycle_repair"]["name"]$around');
            filters.add('node["shop"="motorcycle"]["name"]$around');
          case POICategory.accommodation:
            filters.add('node["tourism"="hotel"]["name"]$around');
            filters.add('node["tourism"="guest_house"]["name"]$around');
            filters.add('node["tourism"="hostel"]["name"]$around');
            filters.add('node["tourism"="motel"]["name"]$around');
            filters.add('node["tourism"="camp_site"]["name"]$around');
            filters.add('way["tourism"="hotel"]["name"]$around');
          case POICategory.restaurant:
            filters.add('node["amenity"="restaurant"]["name"]$around');
            filters.add('node["amenity"="fast_food"]["name"]$around');
        }
      }
    }

    return '''
[out:json][timeout:40];
(
  ${filters.join('\n  ')}
);
out tags center qt;
''';
  }

  List<LatLng> _samplePoints(List<LatLng> waypoints, int count) {
    if (waypoints.length <= count) return waypoints;
    final sampled = <LatLng>[];
    final interval = waypoints.length / count;
    for (var i = 0; i < count; i++) {
      sampled.add(waypoints[(i * interval).round().clamp(0, waypoints.length - 1)]);
    }
    return sampled;
  }

  List<PointOfInterest> _selectBest(List<PointOfInterest> pois, List<LatLng> waypoints, int maxCount) {
    if (pois.isEmpty || maxCount <= 0) return pois;
    final scored = <({PointOfInterest poi, double along, double off})>[];
    for (final poi in pois) {
      final proj = _projectOntoRoute(poi.coordinate, waypoints);
      scored.add((poi: poi, along: proj.$1, off: proj.$2));
    }
    scored.sort((a, b) => a.off.compareTo(b.off));
    final candidates = scored.take(60).toList()..sort((a, b) => a.along.compareTo(b.along));
    final n = candidates.length;
    if (n <= maxCount) return candidates.map((e) => e.poi).toList();

    final indices = <int>{};
    for (var i = 0; i < maxCount; i++) {
      indices.add(((n - 1) * i / max(1, maxCount - 1)).round());
    }
    return indices.map((i) => candidates[i].poi).toList();
  }

  (double, double) _projectOntoRoute(LatLng p, List<LatLng> waypoints) {
    const scale = 111320.0;
    final cosLat = cos(p.latitude * pi / 180);
    var best = double.infinity;
    var bestAlong = 0.0;
    var acc = 0.0;
    for (var i = 0; i < waypoints.length - 1; i++) {
      final a = waypoints[i];
      final b = waypoints[i + 1];
      final ax = a.longitude * cosLat * scale;
      final ay = a.latitude * scale;
      final bx = b.longitude * cosLat * scale;
      final by = b.latitude * scale;
      final px = p.longitude * cosLat * scale;
      final py = p.latitude * scale;
      final dx = bx - ax;
      final dy = by - ay;
      final len2 = dx * dx + dy * dy;
      var t = len2 == 0 ? 0.0 : ((px - ax) * dx + (py - ay) * dy) / len2;
      t = t.clamp(0.0, 1.0);
      final cx = ax + t * dx;
      final cy = ay + t * dy;
      final perp = sqrt(pow(px - cx, 2) + pow(py - cy, 2));
      if (perp < best) {
        best = perp;
        bestAlong = acc + sqrt(pow(cx - ax, 2) + pow(cy - ay, 2));
      }
      acc += sqrt(dx * dx + dy * dy);
    }
    return (bestAlong, best);
  }

  List<PointOfInterest> _parseElements(List elements) {
    final pois = <PointOfInterest>[];
    for (final el in elements) {
      final tags = el['tags'] as Map<String, dynamic>? ?? {};
      final lat = (el['lat'] as num?)?.toDouble() ?? (el['center']?['lat'] as num?)?.toDouble() ?? 0;
      final lon = (el['lon'] as num?)?.toDouble() ?? (el['center']?['lon'] as num?)?.toDouble() ?? 0;

      final name = tags['name'] ?? tags['tourism'] ?? tags['natural'] ?? tags['amenity'] ?? tags['brand'] ?? '';
      if (name.isEmpty) continue;
      final category = _categorizePOI(tags);
      final description = _buildDescription(tags, category);

      pois.add(PointOfInterest(
        id: '${el['type']}-${el['id']}',
        name: name,
        coordinate: LatLng(lat, lon),
        category: category,
        description: description,
      ));
    }
    return pois;
  }

  POICategory _categorizePOI(Map<String, dynamic> tags) {
    if (tags['tourism'] == 'viewpoint') return POICategory.viewpoint;
    if (tags['mountain_pass'] == 'yes' || tags['natural'] == 'mountain_pass') return POICategory.mountainPass;
    if (tags['tourism'] == 'scenic_route') return POICategory.scenicRoad;
    if (tags['amenity'] == 'fuel') return POICategory.fuel;
    if (tags['shop'] == 'motorcycle_repair' || tags['craft'] == 'motorcycle_repair' || tags['shop'] == 'motorcycle') return POICategory.service;
    if (tags['tourism'] == 'hotel' || tags['tourism'] == 'guest_house' || tags['tourism'] == 'hostel' || tags['tourism'] == 'motel' || tags['tourism'] == 'camp_site') return POICategory.accommodation;
    if (tags['amenity'] == 'restaurant' || tags['amenity'] == 'fast_food') return POICategory.restaurant;
    return POICategory.viewpoint;
  }

  String _buildDescription(Map<String, dynamic> tags, POICategory category) {
    final parts = <String>[];
    if (tags['description'] != null) parts.add(tags['description']);
    if (tags['ele'] != null && (category == POICategory.mountainPass || category == POICategory.viewpoint)) {
      parts.add('Wysokość: ${tags['ele']} m n.p.m.');
    }
    if (tags['cuisine'] != null && category == POICategory.restaurant) parts.add('Kuchnia: ${tags['cuisine']}');
    if (parts.isEmpty) parts.add(category.label);
    return parts.join('\n');
  }

  void dispose() => _client.close();
}

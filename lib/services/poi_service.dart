import 'dart:async';
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

  static bool get isWeb => identical(0, 0.0);

  static const List<String> _endpoints = [
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
    'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
    'https://z.overpass-api.de/api/interpreter',
    'https://lz4.overpass-api.de/api/interpreter',
    'https://overpass-api.de/api/interpreter',
  ];
  static const Duration _timeout = Duration(seconds: 30);
  static const String _userAgent =
      'NaviMot-GO/1.0 (+https://github.com/Jc0o0b/NaviMot-GO)';

  final http.Client _client = http.Client();

  Future<List<PointOfInterest>> fetchPOIsAlongRoute(
    List<LatLng> waypoints, {
    double radius = 10000,
  }) async {
    if (waypoints.isEmpty) return [];
    final samples = _samplePoints(waypoints, 3);
    final query = _buildQuery(samples, radius: radius);
    final pois = await _fetchOverpass(query);
    return _selectBest(pois, waypoints,
        radius: radius, maxCount: markerCountForRoute(waypoints));
  }

  Future<List<PointOfInterest>> fetchPOIsNearLocation(
    LatLng coordinate, {
    double radius = 10000,
    POICategory? category,
  }) async {
    final query = _buildQuery([coordinate], radius: radius, category: category);
    return _fetchOverpass(query);
  }

  Future<List<PointOfInterest>> _fetchOverpass(String query) async {
    final completer = Completer<List<PointOfInterest>>();
    var failed = 0;
    final total = _endpoints.length;

    for (final ep in _endpoints) {
      _fetchOne(ep, query).then((pois) {
        if (!completer.isCompleted) completer.complete(pois);
      }).catchError((_) {
        failed++;
        if (!completer.isCompleted && failed >= total) {
          completer.completeError(
              Exception('wszystkie serwery Overpass są niedostępne'));
        }
      });
    }
    return completer.future;
  }

  Future<List<PointOfInterest>> _fetchOne(String ep, String query) async {
    final response = await _client
        .post(
          Uri.parse(ep),
          headers: isWeb ? null : {'User-Agent': _userAgent},
          body: {'data': query},
        )
        .timeout(_timeout);
    if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
    final body = response.body.trim();
    if (!body.startsWith('{') && !body.startsWith('[')) {
      throw Exception('odpowiedź nie jest JSON');
    }
    final json = jsonDecode(body);
    if (json is! Map<String, dynamic>) throw Exception('nieoczekiwany format');
    final elements = json['elements'] as List? ?? [];
    return _parseElements(elements);
  }

  String _buildQuery(
    List<LatLng> samples, {
    double radius = 10000,
    POICategory? category,
  }) {
    final categories = category != null ? [category] : POICategory.values;
    final statements = <String>[];
    for (final s in samples) {
      final bbox = _bboxFor(s, radius);
      for (final cat in categories) {
        for (final filter in _filtersFor(cat)) {
          statements.add('$filter$bbox;');
        }
      }
    }
    return '''
[out:json][timeout:30];
(
  ${statements.join('\n  ')}
);
out tags center qt;
''';
  }

  List<String> _filtersFor(POICategory cat) {
    switch (cat) {
      case POICategory.viewpoint:
        return [
          'node["tourism"="viewpoint"]["name"]',
          'way["tourism"="viewpoint"]["name"]',
        ];
      case POICategory.mountainPass:
        return [
          'node["mountain_pass"="yes"]["name"]',
          'node["natural"="mountain_pass"]["name"]',
        ];
      case POICategory.scenicRoad:
        return ['way["tourism"="scenic_route"]["name"]'];
      case POICategory.fuel:
        return ['node["amenity"="fuel"]["name"]'];
      case POICategory.service:
        return [
          'node["shop"~"motorcycle"]["name"]',
          'node["craft"="motorcycle_repair"]["name"]',
        ];
      case POICategory.accommodation:
        return ['node["tourism"~"^(hotel|guest_house|hostel|motel|camp_site)\$"]["name"]'];
      case POICategory.restaurant:
        return ['node["amenity"~"^(restaurant|fast_food)\$"]["name"]'];
    }
  }

  String _bboxFor(LatLng p, double radius) {
    final dLat = radius / 111320.0 * 1.1;
    final cosLat = max(cos(p.latitude * pi / 180), 0.1);
    final dLon = radius / (111320.0 * cosLat) * 1.1;
    return '(${(p.latitude - dLat).toStringAsFixed(5)},'
        '${(p.longitude - dLon).toStringAsFixed(5)},'
        '${(p.latitude + dLat).toStringAsFixed(5)},'
        '${(p.longitude + dLon).toStringAsFixed(5)})';
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

  List<PointOfInterest> _selectBest(
    List<PointOfInterest> pois,
    List<LatLng> waypoints, {
    required double radius,
    required int maxCount,
  }) {
    if (pois.isEmpty || maxCount <= 0) return pois;
    final scored = <({PointOfInterest poi, double along, double off})>[];
    for (final poi in pois) {
      final proj = _projectOntoRoute(poi.coordinate, waypoints);
      if (proj.$2 > radius) continue;
      scored.add((poi: poi, along: proj.$1, off: proj.$2));
    }
    if (scored.isEmpty) return [];

    final perCategoryCap = max(3, maxCount ~/ 2);
    final byCategory = <POICategory, List<({PointOfInterest poi, double along, double off})>>{};
    for (final s in scored) {
      byCategory.putIfAbsent(s.poi.category, () => []).add(s);
    }
    final candidates = <({PointOfInterest poi, double along, double off})>[];
    for (final list in byCategory.values) {
      list.sort((a, b) => a.off.compareTo(b.off));
      candidates.addAll(list.take(perCategoryCap));
    }
    candidates.sort((a, b) => a.along.compareTo(b.along));
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
    if ((tags['shop'] ?? '').toString().contains('motorcycle') || tags['craft'] == 'motorcycle_repair') return POICategory.service;
    if (const {'hotel', 'guest_house', 'hostel', 'motel', 'camp_site'}.contains(tags['tourism'])) return POICategory.accommodation;
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

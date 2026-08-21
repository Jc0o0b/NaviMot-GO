import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../utils/route_proximity.dart';

/// Pobiera limity prędkości (maxspeed) z OSM wzdłuż trasy przez Overpass API.
class SpeedLimitService {
  static final SpeedLimitService shared = SpeedLimitService._();
  SpeedLimitService._();

  static const List<String> _endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];
  static const double _maxDistanceToRoute = 100;
  static const double _bboxBuffer = 0.02;
  static const Duration _minInterval = Duration(seconds: 2);

  final http.Client _client = http.Client();
  final Map<String, List<SpeedLimitSegment>> _bboxCache = {};
  DateTime _lastFetch = DateTime.fromMillisecondsSinceEpoch(0);

  Future<List<SpeedLimitSegment>> limitsForRoute(
      List<LatLng> waypoints) async {
    if (waypoints.length < 2) return const [];
    double minLat = 90, maxLat = -90, minLon = 180, maxLon = -180;
    for (final p in waypoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }
    final key = _bboxKey(minLat, minLon, maxLat, maxLon);
    var cached = _bboxCache[key];
    if (cached == null) {
      cached = await _fetchBbox(minLat, minLon, maxLat, maxLon);
      _bboxCache[key] = cached;
    }
    final result = <SpeedLimitSegment>[];
    for (final seg in cached) {
      if (distanceToRoute(seg.nearestPoint, waypoints) <=
          _maxDistanceToRoute) {
        result.add(seg);
      }
    }
    return result;
  }

  String _bboxKey(
      double minLat, double minLon, double maxLat, double maxLon) {
    double r3(double v) => (v * 1000).roundToDouble() / 1000;
    return '${r3(minLat)},${r3(minLon)},${r3(maxLat)},${r3(maxLon)}';
  }

  Future<List<SpeedLimitSegment>> _fetchBbox(double minLat, double minLon,
      double maxLat, double maxLon) async {
    final south = (minLat - _bboxBuffer).clamp(-90.0, 90.0);
    final west = (minLon - _bboxBuffer).clamp(-180.0, 180.0);
    final north = (maxLat + _bboxBuffer).clamp(-90.0, 90.0);
    final east = (maxLon + _bboxBuffer).clamp(-180.0, 180.0);
    final query =
        '[out:json][timeout:15];'
        '(way["highway"]["maxspeed"]($south,$west,$north,$east););'
        'out body geom;';
    for (final endpoint in _endpoints) {
      try {
        final wait = _minInterval.inMilliseconds -
            DateTime.now().difference(_lastFetch).inMilliseconds;
        if (wait > 0) {
          await Future<void>.delayed(Duration(milliseconds: wait));
        }
        final resp = await _client
            .get(
              Uri.parse(
                  '$endpoint?data=${Uri.encodeQueryComponent(query)}'),
              headers: {
                'User-Agent':
                    'NaviMot-GO/1.0 (motorcycle route planner; OSM speed limits)',
              },
            )
            .timeout(const Duration(seconds: 20));
        _lastFetch = DateTime.now();
        if (resp.statusCode != 200) continue;
        final json =
            jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        final elements = (json['elements'] as List?) ?? [];
        final segments = <SpeedLimitSegment>[];
        for (final el in elements) {
          final tags = el['tags'] as Map<String, dynamic>?;
          final maxspeedRaw = tags?['maxspeed'] as String?;
          if (maxspeedRaw == null) continue;
          final limit = int.tryParse(maxspeedRaw);
          if (limit == null || limit <= 0) continue;
          final geometry = el['geometry'] as List?;
          if (geometry == null || geometry.length < 2) continue;
          final points = <LatLng>[];
          for (final g in geometry) {
            final lat = (g['lat'] as num?)?.toDouble();
            final lon = (g['lon'] as num?)?.toDouble();
            if (lat != null && lon != null) {
              points.add(LatLng(lat, lon));
            }
          }
          if (points.isEmpty) continue;
          final midIdx = points.length ~/ 2;
          segments.add(SpeedLimitSegment(
            limit: limit,
            points: points,
            nearestPoint: points[midIdx],
          ));
        }
        return segments;
      } catch (_) {
        continue;
      }
    }
    return const [];
  }

  void dispose() => _client.close();
}

class SpeedLimitSegment {
  final int limit;
  final List<LatLng> points;
  final LatLng nearestPoint;

  const SpeedLimitSegment({
    required this.limit,
    required this.points,
    required this.nearestPoint,
  });
}

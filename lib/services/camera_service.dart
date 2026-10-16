import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/road_event.dart';
import '../utils/route_proximity.dart';

/// Pobiera fotoradary i kamery drogowe z OSM (Overpass API) wzdłuż trasy:
/// - fotoradary stacjonarne (`highway=speed_camera`),
/// - kamery na czerwonym świetle (`enforcement=red_light`),
/// - odcinkowy pomiar prędkości (`enforcement=average_speed`).
///
/// Fotoradary mobilne nie występują w OSM — pochodzą ze zgłoszeń kierowców.
class CameraService {
  static final CameraService shared = CameraService._();
  CameraService._();

  static const List<String> _endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];
  static const double _maxDistanceToRoute = 500;
  static const double _bboxBuffer = 0.04;
  static const Duration _cacheTtl = Duration(minutes: 30);
  static const Duration _minInterval = Duration(seconds: 2);

  final http.Client _client = http.Client();
  final Map<String, List<RoadEvent>> _bboxCache = {};
  final Map<String, DateTime> _cacheTime = {};
  DateTime _lastFetch = DateTime.fromMillisecondsSinceEpoch(0);

  Future<List<RoadEvent>> camerasForRoute(List<LatLng> waypoints) async {
    if (waypoints.length < 2) return const [];
    double minLat = 90, maxLat = -90, minLon = 180, maxLon = -180;
    for (final p in waypoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }
    final key = _bboxKey(minLat, minLon, maxLat, maxLon);
    var bboxCameras = _cachedBbox(key);
    if (bboxCameras == null) {
      bboxCameras = await _fetchBbox(minLat, minLon, maxLat, maxLon);
      _bboxCache[key] = bboxCameras;
      _cacheTime[key] = DateTime.now();
    }
    final result = <String, RoadEvent>{};
    for (final e in bboxCameras) {
      if (distanceToRoute(LatLng(e.lat, e.lon), waypoints) <=
          _maxDistanceToRoute) {
        result[e.id] = e;
      }
    }
    return result.values.toList();
  }

  String _bboxKey(
      double minLat, double minLon, double maxLat, double maxLon) {
    double r3(double v) => (v * 1000).roundToDouble() / 1000;
    return '${r3(minLat)},${r3(minLon)},${r3(maxLat)},${r3(maxLon)}';
  }

  List<RoadEvent>? _cachedBbox(String key) {
    final t = _cacheTime[key];
    if (t == null) return null;
    if (DateTime.now().difference(t) > _cacheTtl) {
      _bboxCache.remove(key);
      _cacheTime.remove(key);
      return null;
    }
    return _bboxCache[key];
  }

  Future<List<RoadEvent>> _fetchBbox(double minLat, double minLon,
      double maxLat, double maxLon) async {
    final south = (minLat - _bboxBuffer).clamp(-90.0, 90.0);
    final west = (minLon - _bboxBuffer).clamp(-180.0, 180.0);
    final north = (maxLat + _bboxBuffer).clamp(-90.0, 90.0);
    final east = (maxLon + _bboxBuffer).clamp(-180.0, 180.0);
    final bbox = '($south,$west,$north,$east)';
    final query =
        '[out:json][timeout:25];'
        '('
        'node["highway"="speed_camera"]$bbox;'
        'node["enforcement"="red_light"]$bbox;'
        'node["enforcement"="average_speed"]$bbox;'
        'node["highway"="speed_camera"]["enforcement"="average_speed"]$bbox;'
        'relation["enforcement"="average_speed"]$bbox;'
        ');'
        'out center tags;';
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
                    'NaviMot-GO/1.0 (motorcycle route planner; OSM speed cameras)',
              },
            )
            .timeout(const Duration(seconds: 30));
        _lastFetch = DateTime.now();
        if (resp.statusCode != 200) continue;
        final json =
            jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        final elements = (json['elements'] as List?) ?? [];
        final cameras = <RoadEvent>[];
        for (final el in elements) {
          final lat = (el['lat'] as num?)?.toDouble() ??
              (el['center']?['lat'] as num?)?.toDouble();
          final lon = (el['lon'] as num?)?.toDouble() ??
              (el['center']?['lon'] as num?)?.toDouble();
          if (lat == null || lon == null) continue;
          final tags = (el['tags'] as Map<String, dynamic>?) ?? const {};
          final type = _cameraType(tags);
          final limit = _parseMaxspeed(tags['maxspeed'] as String?);
          cameras.add(RoadEvent(
            id: 'camera-${el['type']}-${el['id']}',
            type: type,
            lat: lat,
            lon: lon,
            description: _description(type, limit),
            createdAt: DateTime(2000),
            speedLimit: limit,
          ));
        }
        return cameras;
      } catch (_) {
        continue;
      }
    }
    return const [];
  }

  RoadEventType _cameraType(Map<String, dynamic> tags) {
    if (tags['enforcement'] == 'red_light') {
      return RoadEventType.redLightCamera;
    }
    if (tags['enforcement'] == 'average_speed') {
      return RoadEventType.averageSpeedCamera;
    }
    // Fotoradar stacjonarny domyślnie.
    return RoadEventType.speedCameraStationary;
  }

  String? _description(RoadEventType type, int? limit) {
    final base = type.label;
    if (limit == null) return base;
    return '$base, ograniczenie $limit km/h';
  }

  /// Parsuje `maxspeed` z OSM: "50", "50 km/h", "PL:urban" itp.
  int? _parseMaxspeed(String? raw) {
    if (raw == null) return null;
    final match = RegExp(r'\d+').firstMatch(raw);
    if (match == null) return null;
    final value = int.tryParse(match.group(0)!);
    if (value == null || value <= 0 || value > 200) return null;
    return value;
  }

  void dispose() => _client.close();
}

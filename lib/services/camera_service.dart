import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/road_event.dart';
import '../utils/route_proximity.dart';
import 'offline_data.dart';

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
    'https://overpass.private.coffee/api/interpreter',
  ];
  static const double _maxDistanceToRoute = 500;
  static const double _bboxBuffer = 0.04;
  static const Duration _cacheTtl = Duration(minutes: 30);
  static const Duration _emptyCacheTtl = Duration(minutes: 3);
  static const Duration _requestTimeout = Duration(seconds: 45);
  static const Duration _minInterval = Duration(seconds: 2);

  final http.Client _client = http.Client();
  final Map<String, List<RoadEvent>> _bboxCache = {};
  final Map<String, DateTime> _cacheTime = {};
  DateTime _lastFetch = DateTime.fromMillisecondsSinceEpoch(0);

  Future<List<RoadEvent>> camerasForRoute(
    List<LatLng> waypoints, {
    void Function(List<RoadEvent>)? onUpdate,
  }) async {
    if (waypoints.length < 2) return const [];

    // Źródło podstawowe: wbudowana baza offline — zawsze działa, bez internetu.
    final result = <String, RoadEvent>{};
    final offline = await OfflineData.shared.cameras();
    for (var i = 0; i < offline.length; i++) {
      final c = offline[i];
      if (distanceToRoute(LatLng(c.lat, c.lon), waypoints) <=
          _maxDistanceToRoute) {
        result['cam-off-$i'] = RoadEvent(
          id: 'cam-off-$i',
          type: c.type,
          lat: c.lat,
          lon: c.lon,
          description: _description(c.type, c.limit),
          createdAt: DateTime(2000),
          speedLimit: c.limit,
        );
      }
    }
    final base = result.values.toList();

    // Świeże dane z OSM (Overpass) dociągamy w tle i przekazujemy przez
    // [onUpdate] — sieć nigdy nie blokuje pokazania kamer z bazy offline.
    if (onUpdate != null) {
      unawaited(_enrichFromOverpass(
        waypoints,
        Map<String, RoadEvent>.from(result),
        onUpdate,
      ));
    }
    return base;
  }

  Future<void> _enrichFromOverpass(
    List<LatLng> waypoints,
    Map<String, RoadEvent> base,
    void Function(List<RoadEvent>) onUpdate,
  ) async {
    try {
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
        final fetched = await _fetchBbox(minLat, minLon, maxLat, maxLon);
        if (fetched != null) {
          _bboxCache[key] = fetched;
          _cacheTime[key] = DateTime.now();
        }
        bboxCameras = fetched ?? const <RoadEvent>[];
      }
      final merged = Map<String, RoadEvent>.from(base);
      for (final e in bboxCameras) {
        if (distanceToRoute(LatLng(e.lat, e.lon), waypoints) <=
            _maxDistanceToRoute) {
          merged.putIfAbsent(e.id, () => e);
        }
      }
      onUpdate(merged.values.toList());
    } catch (_) {
      // Overpass niedostępny — zostaje wynik offline.
    }
  }

  String _bboxKey(
      double minLat, double minLon, double maxLat, double maxLon) {
    double r3(double v) => (v * 1000).roundToDouble() / 1000;
    return '${r3(minLat)},${r3(minLon)},${r3(maxLat)},${r3(maxLon)}';
  }

  List<RoadEvent>? _cachedBbox(String key) {
    final t = _cacheTime[key];
    if (t == null) return null;
    final list = _bboxCache[key];
    // Pusty wynik (możliwy np. przy chwilowym braku odpowiedzi serwera)
    // cache'ujemy krótko, pełny wynik znacznie dłużej.
    final ttl = (list == null || list.isEmpty) ? _emptyCacheTtl : _cacheTtl;
    if (DateTime.now().difference(t) > ttl) {
      _bboxCache.remove(key);
      _cacheTime.remove(key);
      return null;
    }
    return list;
  }

  /// Zwraca `null`, gdy żadne źródło nie odpowiedziało poprawnie
  /// (błąd sieci / HTTP 5xx). Pusty wynik nie jest błędem.
  Future<List<RoadEvent>?> _fetchBbox(double minLat, double minLon,
      double maxLat, double maxLon) async {
    final south = (minLat - _bboxBuffer).clamp(-90.0, 90.0);
    final west = (minLon - _bboxBuffer).clamp(-180.0, 180.0);
    final north = (maxLat + _bboxBuffer).clamp(-90.0, 90.0);
    final east = (maxLon + _bboxBuffer).clamp(-180.0, 180.0);
    final bbox = '($south,$west,$north,$east)';

    // Węzły: `out body;` (zawiera współrzędne) — szybkie i niezawodne.
    final nodes = await _runOverpass(
      '[out:json][timeout:30];'
      '('
      'node["highway"="speed_camera"]$bbox;'
      'node["enforcement"="red_light"]$bbox;'
      'node["enforcement"="average_speed"]$bbox;'
      ');'
      'out body;',
    );
    if (nodes == null) return null;
    final cameras = <RoadEvent>[...nodes];

    // Odcinkowy pomiar prędkości bywa mapowany jako relacja — wymaga `center`,
    // ale traktujemy to jako best-effort (błąd nie psuje wyniku).
    final relations = await _runOverpass(
      '[out:json][timeout:30];'
      'relation["enforcement"="average_speed"]$bbox;'
      'out center;',
    );
    if (relations != null) cameras.addAll(relations);

    return cameras;
  }

  Future<List<RoadEvent>?> _runOverpass(String query) async {
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
            .timeout(_requestTimeout);
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
    return null;
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

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/route.dart';
import '../models/route_step.dart';
import '../utils/scenic_route_calculator.dart';

class RoutingService {
  static final RoutingService _instance = RoutingService._();
  static RoutingService get shared => _instance;
  RoutingService._();

  final http.Client _client = http.Client();

  String _baseUrl(bool avoidHighways) {
    return avoidHighways
        ? 'https://routing.openstreetmap.de/routed-bike/route/v1/cycling'
        : 'https://routing.openstreetmap.de/routed-car/route/v1/driving';
  }

  Future<MotorcycleRoute> calculateRoute({
    required LatLng start,
    required LatLng end,
    List<LatLng> waypoints = const [],
    List<LatLng> intermediateWaypoints = const [],
    bool avoidHighways = true,
    String? label,
  }) async {
    final allCoords = [start, ...waypoints, end];
    final coordStr = allCoords.map((c) => '${c.longitude},${c.latitude}').join(';');

    var url = '${_baseUrl(avoidHighways)}/$coordStr';
    final params = <String>['geometries=geojson', 'overview=full', 'steps=true', 'continue_straight=false'];
    url += '?${params.join('&')}';

    final uri = Uri.parse(Uri.encodeFull(url));
    final response = await _client.get(uri);

    if (response.statusCode != 200) throw Exception('OSRM error: ${response.statusCode}');

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return _parseOSRMResponse(json, allCoords,
        intermediateWaypoints: intermediateWaypoints, label: label);
  }

  MotorcycleRoute _parseOSRMResponse(
    Map<String, dynamic> json,
    List<LatLng> waypoints, {
    List<LatLng> intermediateWaypoints = const [],
    String? label,
  }) {
    final routes = json['routes'] as List?;
    if (routes == null || routes.isEmpty) throw Exception('No route found');

    final route = routes[0] as Map<String, dynamic>;
    final geometry = route['geometry'] as Map<String, dynamic>?;
    final legs = route['legs'] as List?;

    final coordinates = <LatLng>[];
    if (geometry != null) {
      final coordsList = geometry['coordinates'] as List;
      for (final c in coordsList) {
        final coord = c as List;
        coordinates.add(LatLng(coord[1] as double, coord[0] as double));
      }
    }

    final distance = (route['distance'] as num?)?.toDouble() ?? 0;
    final duration = (route['duration'] as num?)?.toDouble() ?? 0;
    final roadTypes = _classifyRoadTypes(coordinates, legs);
    final steps = _parseSteps(legs);

    final scenicScore = ScenicRouteCalculator.shared.calculateScenicScore(
      distance: distance,
      roadTypes: roadTypes,
      coordinates: coordinates,
    );

    return MotorcycleRoute(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      waypoints: coordinates,
      name: 'Trasa ${_formatDistance(distance)}',
      totalDistance: distance,
      estimatedDuration: duration,
      scenicScore: scenicScore,
      roadTypes: roadTypes,
      steps: steps,
      intermediateWaypoints: intermediateWaypoints,
      label: label,
    );
  }

  Future<List<MotorcycleRoute>> calculateAlternatives({
    required LatLng start,
    required LatLng end,
    List<LatLng> waypoints = const [],
    List<LatLng>? scenicWaypoints,
    List<LatLng> intermediateWaypoints = const [],
  }) async {
    final results = await Future.wait([
      calculateRoute(
        start: start,
        end: end,
        waypoints: scenicWaypoints ?? waypoints,
        intermediateWaypoints: intermediateWaypoints,
        avoidHighways: true,
        label: 'Malownicza',
      ),
      calculateRoute(
        start: start,
        end: end,
        waypoints: waypoints,
        intermediateWaypoints: intermediateWaypoints,
        avoidHighways: false,
        label: 'Najszybsza',
      ),
    ]);
    return results;
  }

  List<RouteStep> _parseSteps(List? legs) {
    final steps = <RouteStep>[];
    if (legs == null) return steps;
    for (final leg in legs) {
      final legSteps = leg['steps'] as List? ?? [];
      for (final s in legSteps) {
        final maneuver = s['maneuver'] as Map<String, dynamic>? ?? {};
        final loc = maneuver['location'] as List? ?? [];
        final geometry = s['geometry'] as Map<String, dynamic>?;
        final coords = geometry?['coordinates'] as List? ?? [];
        steps.add(RouteStep(
          type: maneuver['type'] as String? ?? 'continue',
          modifier: maneuver['modifier'] as String?,
          name: s['name'] as String? ?? '',
          ref: s['ref'] as String? ?? '',
          location: loc.length >= 2
              ? LatLng((loc[1] as num).toDouble(), (loc[0] as num).toDouble())
              : const LatLng(0, 0),
          distance: (s['distance'] as num?)?.toDouble() ?? 0,
          duration: (s['duration'] as num?)?.toDouble() ?? 0,
          geometry: coords
              .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
              .toList(),
        ));
      }
    }
    return steps;
  }

  List<RoadType> _classifyRoadTypes(List<LatLng> coordinates, List? legs) {
    final types = <RoadType>{};

    if (legs != null) {
      for (final leg in legs) {
        final steps = leg['steps'] as List?;
        if (steps == null) continue;
        for (final step in steps) {
          final name = (step['name'] as String? ?? '').toLowerCase();
          final ref = (step['ref'] as String? ?? '').toLowerCase();
          final combined = '$name $ref';
          if (_isHighway(combined)) {
            types.add(RoadType.highway);
          } else if (_isExpressway(combined)) {
            types.add(RoadType.expressway);
          } else if (_isNational(combined)) {
            types.add(RoadType.national);
          } else if (_isRegional(combined)) {
            types.add(RoadType.regional);
          } else {
            types.add(RoadType.local);
          }
        }
      }
    }

    if (coordinates.length > 10) {
      var totalDist = 0.0;
      for (var i = 0; i < coordinates.length - 1; i++) {
        totalDist += _distanceBetween(coordinates[i], coordinates[i + 1]);
      }
      final straightLine = _distanceBetween(coordinates.first, coordinates.last);
      final twistiness = totalDist / (straightLine > 0 ? straightLine : 1);
      if (twistiness > 1.5) types.add(RoadType.scenic);
    }

    if (types.isEmpty) types.add(RoadType.national);

    var sorted = types.toList();
    sorted.sort((a, b) => b.scenicWeight.compareTo(a.scenicWeight));
    return sorted;
  }

  bool _isHighway(String s) => s.contains('autostrada') || RegExp(r'(^|\s)a\d+').hasMatch(s);
  bool _isExpressway(String s) => s.contains('ekspresowa') || RegExp(r'(^|\s)s\d+').hasMatch(s);
  bool _isNational(String s) =>
      s.contains('krajowa') || RegExp(r'(^|\s)dk\d+').hasMatch(s) || RegExp(r'(^|\s)\d{1,2}\b').hasMatch(s);
  bool _isRegional(String s) =>
      s.contains('wojewódzka') || RegExp(r'(^|\s)dw\d+').hasMatch(s) || RegExp(r'(^|\s)\d{3}\b').hasMatch(s);

  double _distanceBetween(LatLng a, LatLng b) {
    final dx = a.latitude - b.latitude;
    final dy = a.longitude - b.longitude;
    return (dx * dx + dy * dy).clamp(0, double.infinity);
  }

  String _formatDistance(double meters) {
    final km = meters / 1000.0;
    return km >= 100 ? '${km.toInt()} km' : '${km.toStringAsFixed(1)} km';
  }

  void dispose() => _client.close();
}

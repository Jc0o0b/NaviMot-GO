import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/route.dart';
import '../models/route_step.dart';
import '../utils/route_format.dart';
import '../utils/route_geometry.dart';
import '../utils/scenic_route_calculator.dart';

/// Wyznaczanie tras przez publiczną instancję Valhalli (valhalla1.openstreetmap.de).
///
/// Wykorzystywany wtedy, gdy trasa ma faktycznie omijać autostrady/płatne —
/// OSRM (routing.openstreetmap.de) nie wspiera `exclude`, a przełącznik
/// `avoidHighways` musiałby być wtedy martwy.
///
/// Instancja OSM nie zwraca pól `name`/`ref`, dlatego nazwy dróg są
/// wyciągane z pola `instruction` ("Turn right onto Emilii Plater.").
class ValhallaRoutingService {
  static final ValhallaRoutingService _instance = ValhallaRoutingService._();
  static ValhallaRoutingService get shared => _instance;
  ValhallaRoutingService._();

  static const String _endpoint = 'https://valhalla1.openstreetmap.de/route';

  final http.Client _client = http.Client();

  /// Wyznacza trasę omijającą autostrady i/lub drogi płatne.
  Future<MotorcycleRoute> calculateRoute({
    required LatLng start,
    required LatLng end,
    List<LatLng> waypoints = const [],
    List<LatLng> intermediateWaypoints = const [],
    bool excludeHighways = false,
    bool excludeTolls = false,
    String? label,
  }) async {
    final locations = <Map<String, double>>[
      {'lat': start.latitude, 'lon': start.longitude},
      for (final w in waypoints) {'lat': w.latitude, 'lon': w.longitude},
      {'lat': end.latitude, 'lon': end.longitude},
    ];

    final json = <String, dynamic>{
      'locations': locations,
      'costing': 'auto',
      'costing_options': {
        'auto': {
          if (excludeHighways) 'exclude_highways': true,
          if (excludeTolls) 'exclude_tolls': true,
        },
      },
      'directions_options': {'units': 'kilometers'},
    };

    final uri =
        Uri.parse('$_endpoint?json=${Uri.encodeFull(jsonEncode(json))}');
    final response =
        await _client.get(uri).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Valhalla error: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded['trip'] == null) {
      final err = decoded['error']?['message'] ?? 'no trip';
      throw Exception('Valhalla: $err');
    }

    return _parse(decoded['trip'] as Map<String, dynamic>,
        intermediateWaypoints: intermediateWaypoints, label: label);
  }

  MotorcycleRoute _parse(
    Map<String, dynamic> trip, {
    List<LatLng> intermediateWaypoints = const [],
    String? label,
  }) {
    final summary = trip['summary'] as Map<String, dynamic>? ?? {};
    final legs = trip['legs'] as List? ?? const [];

    final coordinates = <LatLng>[];
    final steps = <RouteStep>[];
    final roadNames = <String>[];

    for (var legIndex = 0; legIndex < legs.length; legIndex++) {
      final leg = legs[legIndex] as Map<String, dynamic>;
      final shape = leg['shape'] as String? ?? '';
      final legPoints = decodePolyline6(shape);

      // Indeksy manewrów są względne do kształtu danej nogi; po sklejeniu
      // nóg przesuwamy je o liczbę punktów zebranych dotychczas.
      final offset = coordinates.isEmpty ? 0 : coordinates.length - 1;

      if (coordinates.isEmpty) {
        coordinates.addAll(legPoints);
      } else if (legPoints.isNotEmpty) {
        // Pomijamy pierwszy punkt nóg — jest powtórzeniem końca poprzedniej.
        coordinates.addAll(legPoints.skip(1));
      }

      final maneuvers = leg['maneuvers'] as List? ?? const [];
      for (var i = 0; i < maneuvers.length; i++) {
        final m = maneuvers[i] as Map<String, dynamic>;
        final type = (m['type'] as num?)?.toInt() ?? 0;
        final begin = ((m['begin_shape_index'] as num?)?.toInt() ?? 0) + offset;
        final instruction = m['instruction'] as String? ?? '';
        final name = roadNameFrom(instruction);
        if (name.isNotEmpty) roadNames.add(name);

        final isFirst = steps.isEmpty;
        final isLast = legIndex == legs.length - 1 && i == maneuvers.length - 1;
        final modifier = (isFirst || isLast)
            ? null
            : _osrmModifier(
                type,
                (m['bearing_before'] as num?)?.toDouble() ?? 0,
                (m['bearing_after'] as num?)?.toDouble() ?? 0,
              );
        final osrmType = isLast
            ? 'arrive'
            : isFirst
                ? 'depart'
                : _osrmType(type, modifier);

        final duration = (m['time'] as num?)?.toDouble() ?? 0;
        final distance = ((m['length'] as num?)?.toDouble() ?? 0) * 1000;

        // Punkt, w którym zaczyna się manewr.
        final location = (begin < coordinates.length)
            ? coordinates[begin]
            : (coordinates.isNotEmpty ? coordinates.last : const LatLng(0, 0));

        steps.add(RouteStep(
          type: osrmType,
          modifier: modifier,
          name: name,
          ref: '',
          location: location,
          distance: distance,
          duration: duration,
          geometry: _stepGeometry(coordinates, begin,
              ((m['end_shape_index'] as num?)?.toInt() ?? 0) + offset),
        ));
      }
    }

    final distance = ((summary['length'] as num?)?.toDouble() ?? 0) * 1000;
    final duration = (summary['time'] as num?)?.toDouble() ?? 0;

    if (coordinates.length < 2) {
      throw Exception('Valhalla: pusta geometria trasy');
    }

    final roadTypes = _classifyRoadTypes(coordinates, roadNames);

    final scenicScore = ScenicRouteCalculator.shared.calculateScenicScore(
      distance: distance,
      roadTypes: roadTypes,
      coordinates: coordinates,
    );

    return MotorcycleRoute(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      waypoints: coordinates,
      name: 'Trasa ${RouteFormat.distance(distance)}',
      totalDistance: distance,
      estimatedDuration: duration,
      scenicScore: scenicScore,
      roadTypes: roadTypes,
      steps: steps,
      intermediateWaypoints: intermediateWaypoints,
      label: label,
    );
  }

  List<LatLng> _stepGeometry(List<LatLng> all, int begin, int end) {
    if (begin < 0 || begin >= all.length) return const [];
    final to = end.clamp(begin, all.length - 1);
    return all.sublist(begin, to + 1);
  }

  /// Valhalla nie zwraca `name`, tylko instrukcję narracyjną.
  /// "Turn right onto Emilii Plater." → "Emilii Plater".
  static final RegExp _namePattern = RegExp(r'\b(?:on|onto)\s+(.+?)\.?$');

  static String roadNameFrom(String instruction) {
    if (instruction.isEmpty) return '';
    final m = _namePattern.firstMatch(instruction);
    if (m == null) return '';
    return m.group(1)!.trim();
  }

  /// Typ manewru Valhalli → typ zgodny z formatem OSRM (NavigationService).
  ///
  /// Numery typów Valhalli nie są stabilne w całej ich historii, dlatego
  /// kierunek (prosto/skręt) ustalamy na podstawie zmodifikowanego
  /// [modifier] liczonego z bearingów, a typu specjalne rozpoznajemy
  /// po zakresie numerów.
  static String _osrmType(int type, String? modifier) {
    if (type >= 26 && type <= 31) return 'roundabout';
    if (type >= 17 && type <= 20) return 'fork';
    if (type >= 21 && type <= 22) return 'end of road';
    if (modifier == 'straight') return 'continue';
    if (modifier == null) return 'continue';
    return 'turn';
  }

  /// Modyfikator kierunku liczony z różnicy bearingów — Valhalla nie zwraca
  /// pola `modifier`, a numeracja typów bywa myląca (type=15 to "Turn left").
  static String? _osrmModifier(int type, double before, double after) {
    if (type >= 23 && type <= 25) return 'uturn';
    if (type >= 32 && type <= 33) return 'uturn';

    var delta = after - before;
    while (delta > 180) {
      delta -= 360;
    }
    while (delta < -180) {
      delta += 360;
    }

    final abs = delta.abs();
    if (abs < 20) return 'straight';
    if (abs > 150) return 'uturn';
    if (delta > 0) {
      if (abs < 45) return 'slight right';
      if (abs < 135) return 'right';
      return 'sharp right';
    }
    if (abs < 45) return 'slight left';
    if (abs < 135) return 'left';
    return 'sharp left';
  }

  /// Klasyfikacja typów dróg na podstawie nazw manewrów (jak w OSRM).
  static List<RoadType> _classifyRoadTypes(
      List<LatLng> coordinates, List<String> names) {
    final types = <RoadType>{};

    for (final raw in names) {
      final s = raw.toLowerCase();
      if (_isHighway(s)) {
        types.add(RoadType.highway);
      } else if (_isExpressway(s)) {
        types.add(RoadType.expressway);
      } else if (_isNational(s)) {
        types.add(RoadType.national);
      } else if (_isRegional(s)) {
        types.add(RoadType.regional);
      } else {
        types.add(RoadType.local);
      }
    }

    if (coordinates.length > 10) {
      var totalDist = 0.0;
      for (var i = 0; i < coordinates.length - 1; i++) {
        totalDist +=
            RouteGeometry.haversine(coordinates[i], coordinates[i + 1]);
      }
      final straight =
          RouteGeometry.haversine(coordinates.first, coordinates.last);
      if (straight > 0 && totalDist / straight > 1.5) {
        types.add(RoadType.scenic);
      }
    }

    if (types.isEmpty) types.add(RoadType.national);

    final sorted = types.toList()
      ..sort((a, b) => b.scenicWeight.compareTo(a.scenicWeight));
    return sorted;
  }

  static bool _isHighway(String s) =>
      s.contains('autostrada') || RegExp(r'(^|\s)a\d+').hasMatch(s);
  static bool _isExpressway(String s) =>
      s.contains('ekspresowa') || RegExp(r'(^|\s)s\d+').hasMatch(s);
  static bool _isNational(String s) =>
      s.contains('krajowa') ||
      RegExp(r'(^|\s)dk\d+').hasMatch(s) ||
      RegExp(r'(^|\s)\d{1,2}\b').hasMatch(s);
  static bool _isRegional(String s) =>
      s.contains('wojewódzka') ||
      RegExp(r'(^|\s)dw\d+').hasMatch(s) ||
      RegExp(r'(^|\s)\d{3}\b').hasMatch(s);

  /// Dekoduje polyline o precyzji 6 miejsc po przecinku (format Valhalli).
  static List<LatLng> decodePolyline6(String encoded) {
    final points = <LatLng>[];
    if (encoded.isEmpty) return points;

    var index = 0;
    var lat = 0;
    var lng = 0;

    while (index < encoded.length) {
      var result = 0;
      var shift = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);
      lat += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));

      result = 0;
      shift = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);
      lng += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));

      points.add(LatLng(lat / 1e6, lng / 1e6));
    }
    return points;
  }

  void dispose() => _client.close();
}

import 'package:latlong2/latlong.dart';
import 'route_step.dart';

class MotorcycleRoute {
  final String id;
  final List<LatLng> waypoints;
  final String name;
  final double totalDistance;
  final double estimatedDuration;
  final int scenicScore;
  final List<RoadType> roadTypes;
  final List<RouteStep> steps;
  final String? label;

  MotorcycleRoute({
    required this.id,
    required this.waypoints,
    required this.name,
    required this.totalDistance,
    required this.estimatedDuration,
    required this.scenicScore,
    required this.roadTypes,
    this.steps = const [],
    this.label,
  });

  factory MotorcycleRoute.preview() {
    return MotorcycleRoute(
      id: 'preview',
      waypoints: [
        const LatLng(52.2297, 21.0122),
        const LatLng(50.0647, 19.9450),
      ],
      name: 'Warszawa - Kraków',
      totalDistance: 293000,
      estimatedDuration: 14400,
      scenicScore: 85,
      roadTypes: [RoadType.highway, RoadType.scenic],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'waypoints': waypoints
        .map((p) => {'lat': p.latitude, 'lon': p.longitude})
        .toList(),
    'name': name,
    'totalDistance': totalDistance,
    'estimatedDuration': estimatedDuration,
    'scenicScore': scenicScore,
    'roadTypes': roadTypes.map((t) => t.name).toList(),
    'steps': steps.map((s) => s.toJson()).toList(),
    'label': label,
  };

  factory MotorcycleRoute.fromJson(Map<String, dynamic> json) {
    RoadType roadTypeFromName(String name) {
      for (final t in RoadType.values) {
        if (t.name == name) return t;
      }
      return RoadType.local;
    }

    return MotorcycleRoute(
      id: json['id'] as String,
      waypoints: (json['waypoints'] as List)
          .map((w) => LatLng(
                (w['lat'] as num).toDouble(),
                (w['lon'] as num).toDouble(),
              ))
          .toList(),
      name: json['name'] as String,
      totalDistance: (json['totalDistance'] as num).toDouble(),
      estimatedDuration: (json['estimatedDuration'] as num).toDouble(),
      scenicScore: (json['scenicScore'] as num?)?.toInt() ?? 0,
      roadTypes: (json['roadTypes'] as List? ?? [])
          .map((t) => roadTypeFromName(t as String))
          .toList(),
      steps: (json['steps'] as List? ?? [])
          .map((s) => RouteStep.fromJson(s as Map<String, dynamic>))
          .toList(),
      label: json['label'] as String?,
    );
  }
}

enum RoadType {
  highway('Autostrada', 1),
  expressway('Droga ekspresowa', 2),
  national('Droga krajowa', 4),
  regional('Droga wojewódzka', 7),
  local('Droga lokalna', 8),
  scenic('Malownicza', 10),
  unpaved('Nieutwardzona', 3);

  final String label;
  final int scenicWeight;
  const RoadType(this.label, this.scenicWeight);
}

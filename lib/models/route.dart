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

  MotorcycleRoute({
    required this.id,
    required this.waypoints,
    required this.name,
    required this.totalDistance,
    required this.estimatedDuration,
    required this.scenicScore,
    required this.roadTypes,
    this.steps = const [],
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

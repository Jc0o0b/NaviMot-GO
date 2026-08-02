import 'package:latlong2/latlong.dart';

class RouteStep {
  final String type;
  final String? modifier;
  final String name;
  final String ref;
  final LatLng location;
  final double distance;
  final double duration;
  final List<LatLng> geometry;

  const RouteStep({
    required this.type,
    this.modifier,
    required this.name,
    required this.ref,
    required this.location,
    required this.distance,
    required this.duration,
    required this.geometry,
  });
}

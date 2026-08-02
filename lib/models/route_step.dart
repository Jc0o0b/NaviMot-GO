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

  Map<String, dynamic> toJson() => {
    'type': type,
    'modifier': modifier,
    'name': name,
    'ref': ref,
    'location': {'lat': location.latitude, 'lon': location.longitude},
    'distance': distance,
    'duration': duration,
    'geometry': geometry
        .map((p) => {'lat': p.latitude, 'lon': p.longitude})
        .toList(),
  };

  factory RouteStep.fromJson(Map<String, dynamic> j) => RouteStep(
    type: j['type'] as String,
    modifier: j['modifier'] as String?,
    name: j['name'] as String,
    ref: j['ref'] as String,
    location: LatLng(
      (j['location']['lat'] as num).toDouble(),
      (j['location']['lon'] as num).toDouble(),
    ),
    distance: (j['distance'] as num).toDouble(),
    duration: (j['duration'] as num).toDouble(),
    geometry: (j['geometry'] as List)
        .map((p) => LatLng(
          (p['lat'] as num).toDouble(),
          (p['lon'] as num).toDouble(),
        ))
        .toList(),
  );
}

import 'dart:math';
import 'package:latlong2/latlong.dart';

int markerCountForRoute(List<LatLng> waypoints, {int minCount = 3, int maxCount = 8}) {
  if (waypoints.length < 2) return minCount;
  const r = 6371000.0;
  const pi = 3.141592653589793;
  var meters = 0.0;
  for (var i = 1; i < waypoints.length; i++) {
    final a = waypoints[i - 1];
    final b = waypoints[i];
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLon = (b.longitude - a.longitude) * pi / 180;
    final la1 = a.latitude * pi / 180;
    final la2 = b.latitude * pi / 180;
    final h = pow(sin(dLat / 2), 2) + cos(la1) * cos(la2) * pow(sin(dLon / 2), 2);
    meters += 2 * r * asin(sqrt(h));
  }
  return (meters / 1000.0 / 50).floor().clamp(minCount, maxCount);
}

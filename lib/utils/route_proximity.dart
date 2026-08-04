import 'package:latlong2/latlong.dart';

double distanceToRoute(LatLng point, List<LatLng> waypoints) {
  if (waypoints.length < 2) {
    if (waypoints.isEmpty) return double.infinity;
    return Distance().distance(point, waypoints.first);
  }
  final d = Distance();
  var minDist = double.infinity;
  for (var i = 0; i < waypoints.length - 1; i++) {
    final dist = _pointSegmentDistance(point, waypoints[i], waypoints[i + 1], d);
    if (dist < minDist) minDist = dist;
  }
  return minDist;
}

double _pointSegmentDistance(
    LatLng p, LatLng a, LatLng b, Distance d) {
  final abx = b.latitude - a.latitude;
  final aby = b.longitude - a.longitude;
  final apx = p.latitude - a.latitude;
  final apy = p.longitude - a.longitude;
  final ab2 = abx * abx + aby * aby;
  if (ab2 == 0) return d.distance(p, a);
  var t = (apx * abx + apy * aby) / ab2;
  t = t.clamp(0.0, 1.0).toDouble();
  return d.distance(
    p,
    LatLng(a.latitude + t * abx, a.longitude + t * aby),
  );
}

List<T> itemsWithinRoute<T>(
  List<T> items,
  List<LatLng> waypoints,
  double maxMeters,
  LatLng Function(T) coords,
) {
  if (waypoints.isEmpty || items.isEmpty) return [];
  return items
      .where((item) => distanceToRoute(coords(item), waypoints) <= maxMeters)
      .toList();
}

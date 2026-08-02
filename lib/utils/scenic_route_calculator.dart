import 'dart:math';
import 'package:latlong2/latlong.dart';
import '../models/route.dart';

class ScenicRouteCalculator {
  static final ScenicRouteCalculator _instance = ScenicRouteCalculator._();
  static ScenicRouteCalculator get shared => _instance;
  ScenicRouteCalculator._();

  int calculateScenicScore({
    required double distance,
    required List<RoadType> roadTypes,
    required List<LatLng> coordinates,
  }) {
    var score = 0;

    for (final type in roadTypes) {
      score += type.scenicWeight * 10;
    }

    final twistiness = _calculateTwistiness(coordinates);
    score += (twistiness * 20).toInt();

    final elevationChange = _estimateElevationChange(coordinates);
    score += (elevationChange / 10).toInt().clamp(0, 30);

    final distanceKm = distance / 1000.0;
    if (distanceKm > 100 && distanceKm < 400) {
      score += 15;
    }

    return score.clamp(0, 100);
  }

  double _calculateTwistiness(List<LatLng> coordinates) {
    if (coordinates.length < 5) return 1.0;
    var totalAngle = 0.0;
    var segments = 0;

    for (var i = 1; i < coordinates.length - 1; i++) {
      final prev = coordinates[i - 1];
      final curr = coordinates[i];
      final next = coordinates[i + 1];

      final bearing1 = _calculateBearing(prev, curr);
      final bearing2 = _calculateBearing(curr, next);
      totalAngle += (bearing2 - bearing1).abs();
      segments++;
    }

    final avgCurve = totalAngle / max(segments, 1);
    return min(avgCurve / 30.0, 5.0);
  }

  double _calculateBearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * pi / 180;
    final lat2 = to.latitude * pi / 180;
    final lonDiff = (to.longitude - from.longitude) * pi / 180;

    final y = sin(lonDiff) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(lonDiff);
    return atan2(y, x) * 180 / pi;
  }

  double _estimateElevationChange(List<LatLng> coordinates) {
    if (coordinates.length < 3) return 0;
    var totalChange = 0.0;
    for (var i = 1; i < coordinates.length; i++) {
      final latChange = (coordinates[i].latitude - coordinates[i - 1].latitude).abs();
      final lonChange = (coordinates[i].longitude - coordinates[i - 1].longitude).abs();
      if (latChange > 0.001 || lonChange > 0.001) {
        totalChange += 1;
      }
    }
    return totalChange * 5;
  }

  List<LatLng>? suggestScenicDetour(MotorcycleRoute currentRoute, {double maxDetourDistance = 50000}) {
    if (currentRoute.waypoints.length < 4) return null;
    final midIndex = currentRoute.waypoints.length ~/ 2;
    final midPoint = currentRoute.waypoints[midIndex];
    final detourPoint = LatLng(midPoint.latitude + 0.02, midPoint.longitude + 0.02);
    return [detourPoint];
  }
}

import 'dart:math';
import 'package:latlong2/latlong.dart';

/// Pomocnicze funkcje geometrii trasy (wzdłuż tras, interpolacja, wycinanie).
class RouteGeometry {
  RouteGeometry._();

  static const double _earthRadius = 6371000.0;
  static const double _scale = 111320.0;

  static double haversine(LatLng a, LatLng b) {
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLon = (b.longitude - a.longitude) * pi / 180;
    final la1 = a.latitude * pi / 180;
    final la2 = b.latitude * pi / 180;
    final h = pow(sin(dLat / 2), 2) +
        cos(la1) * cos(la2) * pow(sin(dLon / 2), 2);
    return 2 * _earthRadius * asin(sqrt(h));
  }

  /// Skumulowane odległości (m) kolejnych punktów trasy.
  static List<double> cumulativeDistances(List<LatLng> pts) {
    final cum = <double>[0];
    for (var i = 1; i < pts.length; i++) {
      cum.add(cum[i - 1] + haversine(pts[i - 1], pts[i]));
    }
    return cum;
  }

  /// Odległość wzdłuż trasy (m) dla punktu rzutowanego na linię trasy.
  static double alongRoute(LatLng p, List<LatLng> pts, List<double> cum) {
    if (pts.length < 2) return 0;
    var best = double.infinity;
    var bestAlong = 0.0;
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i];
      final b = pts[i + 1];
      final midLat = (a.latitude + b.latitude) / 2 * pi / 180;
      final cosLat = cos(midLat);
      final ax = a.longitude * cosLat * _scale;
      final ay = a.latitude * _scale;
      final bx = b.longitude * cosLat * _scale;
      final by = b.latitude * _scale;
      final px = p.longitude * cosLat * _scale;
      final py = p.latitude * _scale;
      final dx = bx - ax;
      final dy = by - ay;
      final len2 = dx * dx + dy * dy;
      var t = len2 == 0 ? 0.0 : ((px - ax) * dx + (py - ay) * dy) / len2;
      t = t.clamp(0.0, 1.0);
      final cx = ax + t * dx;
      final cy = ay + t * dy;
      final perp = sqrt(pow(px - cx, 2) + pow(py - cy, 2));
      if (perp < best) {
        best = perp;
        bestAlong =
            cum[i] + sqrt(pow(cx - ax, 2) + pow(cy - ay, 2));
      }
    }
    return bestAlong;
  }

  /// Punkt na trasie w odległości [along] (m) od startu.
  static LatLng pointAtAlong(
      double along, List<LatLng> pts, List<double> cum) {
    if (pts.isEmpty) return const LatLng(0, 0);
    if (pts.length == 1 || along <= 0) return pts.first;
    var i = 0;
    while (i < pts.length - 2 && cum[i + 1] < along) {
      i++;
    }
    final segStart = cum[i];
    final segLen = cum[i + 1] - segStart;
    final t = segLen <= 0
        ? 0.0
        : ((along - segStart) / segLen).clamp(0.0, 1.0);
    final a = pts[i];
    final b = pts[i + 1];
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }

  /// Wycina odcinek trasy między [from] a [to] (m wzdłuż trasy).
  static List<LatLng> sliceRoute(
      List<LatLng> pts, List<double> cum, double from, double to) {
    if (from >= to || pts.length < 2) return const [];
    final total = cum.last;
    final clampedFrom = from.clamp(0.0, total);
    final clampedTo = to.clamp(0.0, total);
    if (clampedFrom >= clampedTo) return const [];

    final result = <LatLng>[];
    if (clampedFrom > cum.first) {
      result.add(pointAtAlong(clampedFrom, pts, cum));
    } else {
      result.add(pts.first);
    }
    for (var i = 1; i < pts.length - 1; i++) {
      final c = cum[i];
      if (c > clampedFrom && c < clampedTo) result.add(pts[i]);
    }
    if (clampedTo < total) {
      result.add(pointAtAlong(clampedTo, pts, cum));
    } else {
      result.add(pts.last);
    }
    return result;
  }
}

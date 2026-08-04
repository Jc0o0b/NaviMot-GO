import 'package:latlong2/latlong.dart';
import '../models/road_event.dart';
import '../models/traffic_info.dart';
import '../utils/route_geometry.dart';
import '../utils/route_proximity.dart';

/// Oblicza odcinki z utrudnieniami ruchu (korek, spowolnienie, blokada)
/// wzdłuż trasy w oparciu o dostępne dane (zgłoszenia użytkowników
/// i zdarzenia na drodze).
class TrafficService {
  static final TrafficService shared = TrafficService._();
  TrafficService._();

  static const Set<RoadEventType> _blockTypes = {
    RoadEventType.accident,
    RoadEventType.obstacle,
    RoadEventType.breakdown,
  };

  /// Domyślne parametry zasięgu.
  static const double _corridorMeters = 3000;
  static const double _slowBeforeMeters = 2500;
  static const double _slowAfterMeters = 400;
  static const double _blockBeforeMeters = 700;
  static const double _blockAfterMeters = 150;

  List<TrafficSegment> trafficAlongRoute(
    List<LatLng> waypoints,
    List<RoadEvent> events, {
    double corridorMeters = _corridorMeters,
  }) {
    if (waypoints.length < 2) return const [];
    final cum = RouteGeometry.cumulativeDistances(waypoints);
    final total = cum.last;
    if (total <= 0) return const [];

    final segments = <TrafficSegment>[];
    for (final e in events) {
      if (!_blockTypes.contains(e.type)) continue;
      final p = LatLng(e.lat, e.lon);
      final dist = distanceToRoute(p, waypoints);
      if (dist > corridorMeters) continue;
      final along = RouteGeometry.alongRoute(p, waypoints, cum);

      final slowStart = (along - _slowBeforeMeters).clamp(0.0, total);
      final slowEnd = (along + _slowAfterMeters).clamp(0.0, total);
      final slowPoints =
          RouteGeometry.sliceRoute(waypoints, cum, slowStart, slowEnd);
      if (slowPoints.length >= 2) {
        segments.add(TrafficSegment(
          points: slowPoints,
          severity: TrafficSeverity.slow,
          cause: '${e.type.label} — spowolnienie',
          eventId: e.id,
        ));
      }

      final blockStart = (along - _blockBeforeMeters).clamp(0.0, total);
      final blockEnd = (along + _blockAfterMeters).clamp(0.0, total);
      final blockPoints =
          RouteGeometry.sliceRoute(waypoints, cum, blockStart, blockEnd);
      if (blockPoints.length >= 2) {
        segments.add(TrafficSegment(
          points: blockPoints,
          severity: TrafficSeverity.blocked,
          cause: e.type.label,
          eventId: e.id,
        ));
      }
    }
    return segments;
  }

  bool hasBlock(List<TrafficSegment> segments) =>
      segments.any((s) => s.severity == TrafficSeverity.blocked);

  bool hasSlow(List<TrafficSegment> segments) =>
      segments.any((s) => s.severity == TrafficSeverity.slow);
}

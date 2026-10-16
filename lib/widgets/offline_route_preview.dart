import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import '../models/important_place.dart';
import '../models/point_of_interest.dart';
import '../models/road_event.dart';
import '../models/route.dart';
import '../utils/route_geometry.dart';
import '../widgets/event_widgets.dart' show eventIcon, roadEventColor;
import '../widgets/poi_marker.dart' show poiColor, poiIcon;

class OfflineRoutePreview extends StatelessWidget {
  final MotorcycleRoute route;
  final List<RoadEvent> events;
  final List<ImportantPlace> places;
  final List<PointOfInterest> pois;

  /// Etykieta w rogu podglądu; null ukrywa etykietę.
  final String? label;

  const OfflineRoutePreview({
    super.key,
    required this.route,
    this.events = const [],
    this.places = const [],
    this.pois = const [],
    this.label = 'Podgląd trasy (offline)',
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CustomPaint(
        size: Size.infinite,
        painter: _RoutePreviewPainter(
          waypoints: route.waypoints,
          intermediateWaypoints: route.intermediateWaypoints,
          events: events,
          places: places,
          pois: pois,
          label: label,
        ),
      ),
    );
  }
}

class _RoutePreviewPainter extends CustomPainter {
  final List<LatLng> waypoints;
  final List<LatLng> intermediateWaypoints;
  final List<RoadEvent> events;
  final List<ImportantPlace> places;
  final List<PointOfInterest> pois;
  final String? label;

  _RoutePreviewPainter({
    required this.waypoints,
    this.intermediateWaypoints = const [],
    this.events = const [],
    this.places = const [],
    this.pois = const [],
    this.label = 'Podgląd trasy (offline)',
  });

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xFFFFF8F1);
    canvas.drawRect(Offset.zero & size, background);

    if (waypoints.length < 2) {
      final paint = Paint()
        ..color = Colors.grey
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawLine(
        Offset(size.width / 2 - 30, size.height / 2),
        Offset(size.width / 2 + 30, size.height / 2),
        paint,
      );
      return;
    }

    const pad = 18.0;
    double minLat = double.infinity, maxLat = -double.infinity;
    double minLon = double.infinity, maxLon = -double.infinity;
    for (final p in waypoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }
    final latSpan = maxLat - minLat;
    final lonSpan = maxLon - minLon;

    Offset project(LatLng p) {
      double fx = 0.5, fy = 0.5;
      if (lonSpan > 0) fx = (p.longitude - minLon) / lonSpan;
      if (latSpan > 0) fy = (p.latitude - minLat) / latSpan;
      return Offset(
        pad + fx * (size.width - 2 * pad),
        size.height - pad - fy * (size.height - 2 * pad),
      );
    }

    final pts = RouteGeometry.decimate(waypoints, 1000).map(project).toList();

    for (var i = 0; i < pts.length - 1; i++) {
      final halo = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawLine(pts[i], pts[i + 1], halo);

      final road = Paint()
        ..color = const Color(0xFFFF5722)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawLine(pts[i], pts[i + 1], road);
    }

    final start = pts.first;
    final end = pts.last;

    canvas.drawCircle(start, 8, Paint()..color = Colors.white);
    canvas.drawCircle(start, 5, Paint()..color = const Color(0xFFFF5722));

    canvas.drawCircle(end, 8, Paint()..color = Colors.white);
    final flag = Path()
      ..moveTo(end.dx, end.dy - 4)
      ..lineTo(end.dx + 5, end.dy - 2)
      ..lineTo(end.dx, end.dy);
    canvas.drawPath(flag, Paint()..color = Colors.red.shade700);

    for (var i = 0; i < intermediateWaypoints.length; i++) {
      final p = intermediateWaypoints[i];
      if (_inside(p, minLat, maxLat, minLon, maxLon, latSpan, lonSpan)) {
        final o = project(p);
        canvas.drawCircle(o, 9, Paint()..color = Colors.white);
        canvas.drawCircle(o, 6.5, Paint()..color = Colors.blue.shade600);
        final numTp = TextPainter(
          text: TextSpan(
            text: '${i + 1}',
            style: const TextStyle(
                fontSize: 8,
                color: Colors.white,
                fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        numTp.paint(canvas, o - Offset(numTp.width / 2, numTp.height / 2));
      }
    }

    // Najpierw miejsca (POI), potem zdarzenia — żeby alerty/domy były na wierzchu.
    for (final poi in pois) {
      final pos = poi.coordinate;
      if (_inside(pos, minLat, maxLat, minLon, maxLon, latSpan, lonSpan)) {
        _paintBadge(
          canvas,
          project(pos),
          color: poiColor(poi.category),
          icon: poiIcon(poi.category),
          size: 13,
        );
      }
    }

    for (final p in places) {
      final pos = LatLng(p.lat, p.lon);
      if (_inside(pos, minLat, maxLat, minLon, maxLon, latSpan, lonSpan)) {
        _paintBadge(
          canvas,
          project(pos),
          color: const Color(0xFFFFB300),
          icon: Icons.star,
          size: 14,
        );
      }
    }

    for (final e in events) {
      final p = LatLng(e.lat, e.lon);
      if (_inside(p, minLat, maxLat, minLon, maxLon, latSpan, lonSpan)) {
        final o = project(p);
        _paintBadge(
          canvas,
          o,
          color: roadEventColor(e.type),
          icon: eventIcon(e.type),
          size: 15,
        );
        // Limit prędkości dla fotoradarów/kamer.
        final limit = e.speedLimit;
        if (limit != null) {
          _paintSpeedChip(canvas, o, limit);
        }
      }
    }

    if (label != null) {
      final labelTp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
              fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      labelTp.paint(canvas, Offset(10, 8));
    }
  }

  bool _inside(LatLng p, double minLat, double maxLat, double minLon,
      double maxLon, double latSpan, double lonSpan) {
    if (latSpan > 0 && (p.latitude < minLat || p.latitude > maxLat)) {
      return false;
    }
    if (lonSpan > 0 && (p.longitude < minLon || p.longitude > maxLon)) {
      return false;
    }
    return true;
  }

  void _paintBadge(Canvas canvas, Offset center,
      {required Color color, required IconData icon, required double size}) {
    final bg = Paint()..color = Colors.white;
    canvas.drawCircle(center, size / 2 + 2, bg);
    canvas.drawCircle(center, size / 2, Paint()..color = color);
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size - 3,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  /// Maluje mały chip z limitem prędkości (np. "50") obok znacznika kamery.
  void _paintSpeedChip(Canvas canvas, Offset badge, int limit) {
    final text = '$limit';
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = tp.width + 8;
    const h = 12.0;
    // Chip w prawym-dolnym rogu znacznika.
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(
          badge.dx + 4, badge.dy + 4, w, h),
      const Radius.circular(6),
    );
    canvas.drawRRect(r, Paint()..color = Colors.black.withValues(alpha: 0.85));
    tp.paint(canvas, Offset(badge.dx + 8, badge.dy + 6));
  }

  @override
  bool shouldRepaint(covariant _RoutePreviewPainter oldDelegate) =>
      oldDelegate.waypoints != waypoints ||
      oldDelegate.intermediateWaypoints != intermediateWaypoints ||
      oldDelegate.events != events ||
      oldDelegate.places != places ||
      oldDelegate.pois != pois ||
      oldDelegate.label != label;
}

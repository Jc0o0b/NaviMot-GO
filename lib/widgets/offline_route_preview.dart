import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import '../models/important_place.dart';
import '../models/road_event.dart';
import '../models/route.dart';
import '../widgets/event_widgets.dart' show eventIcon;

class OfflineRoutePreview extends StatelessWidget {
  final MotorcycleRoute route;
  final List<RoadEvent> events;
  final List<ImportantPlace> places;

  const OfflineRoutePreview({
    super.key,
    required this.route,
    this.events = const [],
    this.places = const [],
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CustomPaint(
        size: Size.infinite,
        painter: _RoutePreviewPainter(
          waypoints: route.waypoints,
          events: events,
          places: places,
        ),
      ),
    );
  }
}

class _RoutePreviewPainter extends CustomPainter {
  final List<LatLng> waypoints;
  final List<RoadEvent> events;
  final List<ImportantPlace> places;

  _RoutePreviewPainter({
    required this.waypoints,
    this.events = const [],
    this.places = const [],
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

    final pts = waypoints.map(project).toList();

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
    canvas.drawCircle(start, 5, Paint()..color = Colors.green.shade600);

    canvas.drawCircle(end, 8, Paint()..color = Colors.white);
    final flag = Path()
      ..moveTo(end.dx, end.dy - 4)
      ..lineTo(end.dx + 5, end.dy - 2)
      ..lineTo(end.dx, end.dy);
    canvas.drawPath(flag, Paint()..color = Colors.red.shade700);

    for (final e in events) {
      final p = LatLng(e.lat, e.lon);
      if (_inside(p, minLat, maxLat, minLon, maxLon, latSpan, lonSpan)) {
        final o = project(p);
        _paintBadge(
          canvas,
          o,
          color: _eventColor(e.type),
          icon: eventIcon(e.type),
          size: 14,
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

    final label = TextPainter(
      text: const TextSpan(
        text: 'Podgląd trasy (offline)',
        style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(10, 8));
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

  Color _eventColor(RoadEventType type) {
    switch (type) {
      case RoadEventType.police:
        return Colors.blue;
      case RoadEventType.speedCamera:
        return Colors.red;
      case RoadEventType.accident:
        return Colors.deepOrange;
      case RoadEventType.obstacle:
        return Colors.orange;
      case RoadEventType.breakdown:
        return Colors.brown;
    }
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

  @override
  bool shouldRepaint(covariant _RoutePreviewPainter oldDelegate) =>
      oldDelegate.waypoints != waypoints ||
      oldDelegate.events != events ||
      oldDelegate.places != places;
}

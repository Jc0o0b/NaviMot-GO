import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import '../models/route.dart';

class OfflineRoutePreview extends StatelessWidget {
  final MotorcycleRoute route;

  const OfflineRoutePreview({super.key, required this.route});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CustomPaint(
        size: Size.infinite,
        painter: _RoutePreviewPainter(waypoints: route.waypoints),
      ),
    );
  }
}

class _RoutePreviewPainter extends CustomPainter {
  final List<LatLng> waypoints;

  _RoutePreviewPainter({required this.waypoints});

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

    final label = TextPainter(
      text: const TextSpan(
        text: 'Podgląd trasy (offline)',
        style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(10, 8));
  }

  @override
  bool shouldRepaint(covariant _RoutePreviewPainter oldDelegate) =>
      oldDelegate.waypoints != waypoints;
}

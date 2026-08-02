import 'dart:math';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;

class RoadView2D extends StatelessWidget {
  final List<LatLng> path;
  final double headingDeg;

  const RoadView2D({
    super.key,
    required this.path,
    required this.headingDeg,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _RoadPainter2D(path: path, headingDeg: headingDeg),
      ),
    );
  }
}

class _RoadPainter2D extends CustomPainter {
  final List<LatLng> path;
  final double headingDeg;

  static const double _roadHalf = 5.0;
  static const double _visibleAhead = 240.0;

  _RoadPainter2D({required this.path, required this.headingDeg});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final bottom = h - 16;
    final ppm = max(1.0, (h * 0.6) / _visibleAhead);

    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFDCE7D0));

    if (path.length < 2) {
      _drawFlat(canvas, w, bottom, cx, ppm);
      return;
    }

    final pts = _project(cx, bottom, ppm);
    if (pts.length < 2) {
      _drawFlat(canvas, w, bottom, cx, ppm);
      return;
    }

    final left = <Offset>[];
    final right = <Offset>[];
    for (final p in pts) {
      left.add(Offset(p.sx - _roadHalf * ppm, p.sy));
      right.add(Offset(p.sx + _roadHalf * ppm, p.sy));
    }

    final roadPath = Path()
      ..moveTo(right.first.dx, right.first.dy);
    for (final p in right.skip(1)) {
      roadPath.lineTo(p.dx, p.dy);
    }
    for (final p in left.reversed) {
      roadPath.lineTo(p.dx, p.dy);
    }
    roadPath.close();
    canvas.drawPath(roadPath, Paint()..color = const Color(0xFF3A3F44));

    final edge = Paint()
      ..color = const Color(0xFFE9E9E9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawPath(_pathFrom(left), edge);
    canvas.drawPath(_pathFrom(right), edge);

    final centerPts = pts.map((p) => Offset(p.sx, p.sy)).toList();
    final dash = Paint()
      ..color = const Color(0xFFF2C94C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    const dashLen = 20.0;
    const gap = 14.0;
    for (final m in _pathFrom(centerPts).computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        final e = min(d + dashLen, m.length);
        canvas.drawPath(m.extractPath(d, e), dash);
        d = e + gap;
      }
    }

    _drawVehicle(canvas, cx, bottom);
  }

  List<_P2> _project(double cx, double bottom, double ppm) {
    final origin = path.first;
    const scale = 111320.0;
    final cosLat = cos(origin.latitude * pi / 180);
    final hd = headingDeg * pi / 180;
    final sinH = sin(hd);
    final cosH = cos(hd);
    final out = <_P2>[];
    for (final p in path) {
      final east = (p.longitude - origin.longitude) * cosLat * scale;
      final north = (p.latitude - origin.latitude) * scale;
      final forward = east * sinH + north * cosH;
      final lateral = east * cosH - north * sinH;
      if (forward < -8) continue;
      final sy = bottom - forward * ppm;
      if (sy < -40) break;
      out.add(_P2(sx: cx + lateral * ppm, sy: sy));
    }
    return out;
  }

  void _drawFlat(Canvas canvas, double w, double bottom, double cx, double ppm) {
    final left = cx - _roadHalf * ppm;
    final right = cx + _roadHalf * ppm;
    final top = bottom - _visibleAhead * ppm * 0.6;
    final road = Path()
      ..moveTo(right, bottom)
      ..lineTo(right, top)
      ..lineTo(left, top)
      ..lineTo(left, bottom)
      ..close();
    canvas.drawPath(road, Paint()..color = const Color(0xFF3A3F44));
    final edge = Paint()
      ..color = const Color(0xFFE9E9E9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawLine(Offset(left, bottom), Offset(left, top), edge);
    canvas.drawLine(Offset(right, bottom), Offset(right, top), edge);
    final dash = Paint()
      ..color = const Color(0xFFF2C94C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final cy = bottom - (_visibleAhead * ppm * 0.6) / 2;
    canvas.drawLine(Offset(cx, bottom), Offset(cx, cy), dash);
    _drawVehicle(canvas, cx, bottom);
  }

  void _drawVehicle(Canvas canvas, double cx, double bottom) {
    final cy = bottom - 28;
    canvas.drawShadow(
      Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: 15)),
      Colors.black,
      3,
      false,
    );
    canvas.drawCircle(Offset(cx, cy), 15, Paint()..color = const Color(0xFF1565C0));
    canvas.drawCircle(Offset(cx, cy), 15, Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3);
    final arrow = Path()
      ..moveTo(cx, cy - 8)
      ..lineTo(cx - 7, cy + 6)
      ..lineTo(cx + 7, cy + 6)
      ..close();
    canvas.drawPath(arrow, Paint()..color = Colors.white);
  }

  Path _pathFrom(List<Offset> pts) {
    final p = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final o in pts.skip(1)) {
      p.lineTo(o.dx, o.dy);
    }
    return p;
  }

  @override
  bool shouldRepaint(_RoadPainter2D oldDelegate) {
    return oldDelegate.headingDeg != headingDeg || oldDelegate.path != path;
  }
}

class _P2 {
  final double sx;
  final double sy;
  const _P2({required this.sx, required this.sy});
}

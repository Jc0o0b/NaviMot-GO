import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:navimot_go/widgets/road_view_2d.dart';

List<LatLng> _navPath() {
  const scale = 111320.0;
  final pts = <LatLng>[];
  for (var i = 0; i < 60; i++) {
    final d = i * 20.0;
    pts.add(LatLng(52.0 + d * cos(0.7) / scale, 21.0 + d * sin(0.7) / scale));
  }
  return pts;
}

void main() {
  testWidgets('RoadView2D golden', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoadView2D(path: _navPath(), headingDeg: 40),
        ),
      ),
    );
    await expectLater(
      find.byType(RoadView2D),
      matchesGoldenFile('goldens/road_view.png'),
    );
  });
}

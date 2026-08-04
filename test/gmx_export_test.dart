import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:navimot_go/models/route.dart';
import 'package:navimot_go/utils/gmx_builder.dart';

void main() {
  MotorcycleRoute makeRoute() => MotorcycleRoute(
        id: 'g1',
        waypoints: const [
          LatLng(52.1, 21.0),
          LatLng(52.2, 21.1),
          LatLng(52.3, 21.2),
        ],
        name: 'Trasa & test',
        totalDistance: 30000,
        estimatedDuration: 1800,
        scenicScore: 60,
        roadTypes: const [RoadType.local],
      );

  test('GmxBuilder tworzy poprawny GPX z punktami trasy', () {
    final gpx = GmxBuilder.buildGmx(makeRoute());
    expect(gpx, contains('<?xml version="1.0"'));
    expect(gpx, contains('<rte>'));
    expect(gpx, contains('<name>Trasa &amp; test</name>'));
    expect(gpx, contains('<name>Start</name>'));
    expect(gpx, contains('<name>Cel</name>'));
    expect(gpx, contains('lat="52.1"'));
    expect(gpx, contains('lat="52.2"'));
    expect(gpx, contains('lat="52.3"'));
  });

  test('linkUri koduje zawartość GPX jako data URI', () {
    final uri = GmxBuilder.linkUri(makeRoute());
    expect(uri, startsWith('data:application/gpx+xml;charset=utf-8,'));
    expect(Uri.decodeComponent(uri.split(',').last), contains('<gpx'));
    expect(Uri.decodeComponent(uri.split(',').last), contains('Trasa &amp; test'));
  });
}

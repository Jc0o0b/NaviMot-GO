import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:navimot_go/services/offline_data.dart';
import 'package:navimot_go/utils/route_proximity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('baza offline laduje kamery i miejsca z assets', () async {
    final cams = await OfflineData.shared.cameras();
    final pois = await OfflineData.shared.pois();
    expect(cams.length, greaterThan(1000));
    expect(pois.length, greaterThan(1000));
  });

  test('kamery sa znajdowane w korytarzu trasy Gliwice -> Zylina', () async {
    final cams = await OfflineData.shared.cameras();
    final route = <LatLng>[
      const LatLng(50.294, 18.666),
      const LatLng(50.100, 18.690),
      const LatLng(49.820, 18.720),
      const LatLng(49.560, 18.780),
      const LatLng(49.360, 18.780),
      const LatLng(49.223, 18.744),
    ];
    final near = cams
        .where((c) => distanceToRoute(LatLng(c.lat, c.lon), route) <= 5000)
        .toList();
    expect(near.length, greaterThan(0));
  });

  test('miejsca sa znajdowane w korytarzu trasy Gliwice -> Zylina', () async {
    final pois = await OfflineData.shared.pois();
    final route = <LatLng>[
      const LatLng(50.294, 18.666),
      const LatLng(50.100, 18.690),
      const LatLng(49.820, 18.720),
      const LatLng(49.560, 18.780),
      const LatLng(49.360, 18.780),
      const LatLng(49.223, 18.744),
    ];
    final near = pois
        .where((p) => distanceToRoute(p.coordinate, route) <= 5000)
        .toList();
    expect(near.length, greaterThan(0));
  });
}

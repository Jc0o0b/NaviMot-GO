import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:navimot_go/models/route.dart';
import 'package:navimot_go/models/route_step.dart';
import 'package:navimot_go/providers/events_provider.dart';
import 'package:navimot_go/providers/route_provider.dart';
import 'package:navimot_go/screens/navigation_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const List<int> _kTransparentPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

class _InMemoryTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return MemoryImage(Uint8List.fromList(_kTransparentPng));
  }
}

MotorcycleRoute _syntheticRoute() {
  const scale = 111320.0;
  final waypoints = <LatLng>[];
  for (var i = 0; i < 300; i++) {
    final d = i * 50.0;
    waypoints.add(LatLng(
      52.0 + (d * cos(0.7) / scale),
      21.0 + (d * sin(0.7) / scale),
    ));
  }
  return MotorcycleRoute(
    id: 'test',
    waypoints: waypoints,
    name: 'Trasa testowa',
    totalDistance: 15000,
    estimatedDuration: 1200,
    scenicScore: 70,
    roadTypes: const [RoadType.scenic, RoadType.local],
    steps: [
      RouteStep(
        type: 'depart',
        name: '',
        ref: '',
        location: waypoints.first,
        distance: 0,
        duration: 0,
        geometry: [waypoints.first],
      ),
      RouteStep(
        type: 'turn',
        modifier: 'left',
        name: '',
        ref: '',
        location: waypoints[200],
        distance: 10000,
        duration: 800,
        geometry: const [],
      ),
      RouteStep(
        type: 'arrive',
        name: '',
        ref: '',
        location: waypoints.last,
        distance: 5000,
        duration: 400,
        geometry: [waypoints.last],
      ),
    ],
  );
}

void main() {
  testWidgets('tryb demo startuje po 10 s bez GPS i rysuje drogę',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final eventsProvider = EventsProvider();
    await eventsProvider.load();
    final routeProvider = RouteProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: routeProvider),
          ChangeNotifierProvider.value(value: eventsProvider),
        ],
        child: MaterialApp(
          home: NavigationScreen(
            route: _syntheticRoute(),
            tileProvider: _InMemoryTileProvider(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Lokalizowanie...'), findsOneWidget,
        reason: 'przed upływem fallbacku nie ma jeszcze pozycji');
    expect(find.text('Tryb demo'), findsNothing);

    await tester.pump(const Duration(seconds: 11));
    await tester.pump();

    expect(find.text('Tryb demo'), findsOneWidget,
        reason: 'po 10 s bez GPS powinien wejść tryb demo');
    expect(find.text('Lokalizowanie...'), findsNothing,
        reason: 'tryb demo nadaje pozorowaną pozycję');
    expect(find.textContaining('km/h'), findsOneWidget,
        reason: 'simulacja podaje prędkość');

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.textContaining('km/h'), findsOneWidget,
        reason: 'symulacja nadal się przesuwa');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:navimot_go/models/important_place.dart';
import 'package:navimot_go/models/road_event.dart';
import 'package:navimot_go/models/route.dart';
import 'package:navimot_go/models/route_step.dart';
import 'package:navimot_go/models/traffic_regulations.dart';
import 'package:navimot_go/providers/chat_provider.dart';
import 'package:navimot_go/providers/events_provider.dart';
import 'package:navimot_go/providers/route_provider.dart';
import 'package:navimot_go/services/navigation_service.dart';
import 'package:navimot_go/utils/gmx_builder.dart';
import 'package:navimot_go/utils/route_proximity.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('EventsProvider zapisuje wydarzenia i ważne miejsca lokalnie', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = EventsProvider();
    await provider.load();
    await provider.addRoadEvent(
      type: RoadEventType.speedCamera,
      location: const LatLng(52.1, 21.0),
    );
    await provider.addImportantPlace(
      name: 'Panorama',
      note: 'Piękny widok',
      location: const LatLng(52.2, 21.1),
    );
    expect(provider.events.length, 1);
    expect(provider.events.first.type, RoadEventType.speedCamera);
    expect(provider.importantPlaces.length, 1);

    final reloaded = EventsProvider();
    await reloaded.load();
    expect(reloaded.events.length, 1);
    expect(reloaded.importantPlaces.first.name, 'Panorama');
  });

  test('ChatProvider zapisuje wiadomości per województwo', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = ChatProvider();
    await provider.load();
    await provider.send('mazowieckie', 'Kowal', 'Jadę w niedzielę, ktoś chętny?');
    expect(provider.messagesFor('mazowieckie').length, 1);
    expect(provider.messagesFor('slaskie').length, 0);

    final reloaded = ChatProvider();
    await reloaded.load();
    expect(
      reloaded.messagesFor('mazowieckie').first.text,
      'Jadę w niedzielę, ktoś chętny?',
    );
  });

  test('Uproszczone komunikaty nawigacyjne', () {
    final turn = RouteStep(
      type: 'turn',
      modifier: 'right',
      name: 'Prosta',
      ref: '',
      location: const LatLng(52.0, 21.0),
      distance: 100,
      duration: 10,
      geometry: const [],
    );
    expect(
      NavigationService.shared.instructionFor(turn),
      'Skręć w prawo',
    );

    final endOfRoad = RouteStep(
      type: 'end of road',
      modifier: 'left',
      name: '',
      ref: '',
      location: const LatLng(52.0, 21.0),
      distance: 100,
      duration: 10,
      geometry: const [],
    );
    expect(
      NavigationService.shared.instructionFor(endOfRoad),
      'Skręć w lewo',
    );

    final fork = RouteStep(
      type: 'fork',
      modifier: 'right',
      name: '',
      ref: '',
      location: const LatLng(52.0, 21.0),
      distance: 100,
      duration: 10,
      geometry: const [],
    );
    expect(
      NavigationService.shared.instructionFor(fork),
      'Trzymaj się prawej',
    );
  });

  test('MotorcycleRoute zachowuje etykietę trasy (wariant)', () {
    final route = MotorcycleRoute(
      id: 'r1',
      waypoints: const [LatLng(52.1, 21.0), LatLng(52.2, 21.1)],
      name: 'Trasa',
      totalDistance: 10000,
      estimatedDuration: 600,
      scenicScore: 50,
      roadTypes: const [RoadType.local],
      label: 'Najszybsza',
    );
    final restored = MotorcycleRoute.fromJson(route.toJson());
    expect(restored.label, 'Najszybsza');
  });

  test('RouteProvider dodaje i usuwa przystanki bez wyznaczania trasy', () {
    SharedPreferences.setMockInitialValues({});
    final provider = RouteProvider();
    expect(provider.intermediateWaypoints, isEmpty);

    provider.addWaypoint(const LatLng(52.15, 21.05));
    provider.addWaypoint(const LatLng(52.15, 21.05));
    expect(provider.intermediateWaypoints.length, 1);

    provider.addWaypoint(const LatLng(52.2, 21.1));
    expect(provider.intermediateWaypoints.length, 2);

    provider.removeWaypoint(const LatLng(52.15, 21.05));
    expect(provider.intermediateWaypoints.length, 1);
    expect(provider.intermediateWaypoints.single.latitude, 52.2);
  });

  test('RouteProvider.setWaypointOrder zmienia kolejność przystanków', () {
    SharedPreferences.setMockInitialValues({});
    final provider = RouteProvider();
    provider.addWaypoint(const LatLng(52.1, 21.0));
    provider.addWaypoint(const LatLng(52.2, 21.1));
    provider.addWaypoint(const LatLng(52.3, 21.2));

    provider.setWaypointOrder([
      const LatLng(52.3, 21.2),
      const LatLng(52.1, 21.0),
      const LatLng(52.2, 21.1),
    ]);

    expect(provider.intermediateWaypoints[0].latitude, 52.3);
    expect(provider.intermediateWaypoints[1].latitude, 52.1);
    expect(provider.intermediateWaypoints[2].latitude, 52.2);
  });

  test('Czas przejazdu malowniczej trasy liczony jak motocyklowy, nie rowerowy',
      () {
    final scenic = MotorcycleRoute(
      id: 'scenic',
      waypoints: const [LatLng(52.1, 21.0), LatLng(52.2, 21.1)],
      name: 'Malownicza',
      totalDistance: 200000,
      estimatedDuration: 7 * 3600,
      scenicScore: 80,
      roadTypes: const [RoadType.scenic, RoadType.regional],
      label: 'Malownicza',
    );
    final travel = PolishTrafficRegulations.shared.calculateTravelTime(
        scenic.totalDistance, scenic.roadTypes);
    expect(travel.drivingTime, lessThan(7 * 3600));
    expect(travel.drivingTime, greaterThan(0));
  });

  test('RouteProvider.selectRoute ustawia trasę i czas przejazdu', () {
    SharedPreferences.setMockInitialValues({});
    final provider = RouteProvider();
    final fastest = MotorcycleRoute(
      id: 'fast',
      waypoints: const [LatLng(52.1, 21.0), LatLng(52.2, 21.1)],
      name: 'Najszybsza',
      totalDistance: 50000,
      estimatedDuration: 1800,
      scenicScore: 40,
      roadTypes: const [RoadType.highway],
      label: 'Najszybsza',
    );
    provider.selectRoute(fastest);
    expect(provider.currentRoute?.id, 'fast');
    expect(provider.travelTimeInfo, isNotNull);
  });

  test('GmxExporter buduje poprawny plik GMX z trasą', () {
    final route = MotorcycleRoute(
      id: 'r1',
      waypoints: const [
        LatLng(52.2297, 21.0122),
        LatLng(52.24, 21.05),
        LatLng(50.0647, 19.9450),
      ],
      name: 'Warszawa <-> Kraków',
      totalDistance: 293000,
      estimatedDuration: 14400,
      scenicScore: 85,
      roadTypes: const [RoadType.highway],
    );
    final gmx = GmxBuilder.buildGmx(route);
    expect(gmx, contains('<?xml version="1.0" encoding="UTF-8"?>'));
    expect(gmx, contains('<rte>'));
    expect(gmx, contains('<name>Warszawa &lt;-&gt; Kraków</name>'));
    expect(gmx, contains('<rtept lat="52.2297" lon="21.0122">'));
    expect(gmx, contains('<wpt'));
    expect(gmx, contains('</gpx>'));
  });

  test('itemsWithinRoute filtruje punkty blisko trasy', () {
    final waypoints = [
      const LatLng(52.1, 21.0),
      const LatLng(52.2, 21.1),
    ];
    final events = [
      RoadEvent(
        id: 'e1',
        type: RoadEventType.accident,
        lat: 52.15,
        lon: 21.05,
        createdAt: DateTime(2025),
      ),
      RoadEvent(
        id: 'e2',
        type: RoadEventType.police,
        lat: 53.0,
        lon: 22.0,
        createdAt: DateTime(2025),
      ),
    ];
    final near = itemsWithinRoute(
        events, waypoints, 3000, (e) => LatLng(e.lat, e.lon));
    expect(near.length, 1);
    expect(near.first.id, 'e1');
  });

  test('Itemy ważnych miejsc są znajdowane w pobliżu trasy', () {
    final waypoints = [
      const LatLng(52.1, 21.0),
      const LatLng(52.2, 21.1),
    ];
    final places = [
      ImportantPlace(
        id: 'p1',
        name: 'Panorama',
        note: 'Piękny widok',
        lat: 52.15,
        lon: 21.05,
        createdAt: DateTime(2025),
      ),
      ImportantPlace(
        id: 'p2',
        name: 'Daleko',
        note: '',
        lat: 55.0,
        lon: 25.0,
        createdAt: DateTime(2025),
      ),
    ];
    final near = itemsWithinRoute(
        places, waypoints, 3000, (p) => LatLng(p.lat, p.lon));
    expect(near.length, 1);
    expect(near.first.name, 'Panorama');
  });
}

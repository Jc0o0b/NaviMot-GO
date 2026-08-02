import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:navimot_go/models/road_event.dart';
import 'package:navimot_go/models/route_step.dart';
import 'package:navimot_go/providers/chat_provider.dart';
import 'package:navimot_go/providers/events_provider.dart';
import 'package:navimot_go/services/navigation_service.dart';
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

  test('Komunikaty nawigacyjne bez dystansu, z końcem drogi', () {
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
      'skręć w prawo w ulicę Prosta',
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
      'na końcu drogi skręć w lewo',
    );
  });
}

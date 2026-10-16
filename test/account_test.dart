import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:navimot_go/models/road_event.dart';
import 'package:navimot_go/models/user_profile.dart';
import 'package:navimot_go/providers/account_provider.dart';
import 'package:navimot_go/providers/events_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Rejestracja i logowanie e-mailem (konta lokalne)', () async {
    SharedPreferences.setMockInitialValues({});
    final account = AccountProvider();
    await account.load();
    expect(account.isSignedIn, isFalse);

    final ok = await account.signUpWithEmail(
      email: 'Jan@Example.com',
      password: 'tajne123',
      displayName: 'Jan',
    );
    expect(ok, isTrue);
    expect(account.user!.displayName, 'Jan');
    expect(account.user!.email, 'jan@example.com');
    expect(account.user!.points, 0);
    expect(account.user!.level, 1);

    await account.signOut();
    expect(account.isSignedIn, isFalse);

    final wrong = await account.signInWithEmail(
        email: 'jan@example.com', password: 'zlehaslo');
    expect(wrong, isFalse);
    expect(account.error, isNotNull);

    final login = await account.signInWithEmail(
        email: 'jan@example.com', password: 'tajne123');
    expect(login, isTrue);
    expect(account.user!.displayName, 'Jan');

    final restored = AccountProvider();
    await restored.load();
    expect(restored.isSignedIn, isTrue);
    expect(restored.user!.email, 'jan@example.com');
  });

  test('Szybkie logowanie pseudonimem', () async {
    SharedPreferences.setMockInitialValues({});
    final account = AccountProvider();
    await account.load();
    final ok = await account.quickSignIn(nickname: 'Kowal');
    expect(ok, isTrue);
    expect(account.user!.displayName, 'Kowal');
    expect(account.user!.email, isNull);
  });

  test('Zgłaszanie zdarzeń przyznaje punkty i wymaga konta', () async {
    SharedPreferences.setMockInitialValues({});
    final account = AccountProvider();
    await account.load();
    final events = EventsProvider(account: account);

    // Gość: bez punktów.
    await events.addRoadEvent(
        type: RoadEventType.accident, location: const LatLng(52.1, 21.0));
    expect(account.isSignedIn, isFalse);
    expect(events.events.length, 1);
    expect(events.events.first.reporterId, isNull);

    await account.quickSignIn(nickname: 'Kowal');
    await events.addRoadEvent(
        type: RoadEventType.police,
        location: const LatLng(52.2, 21.1),
        speedLimit: 50);
    expect(account.user!.points, PointsRules.report);
    expect(account.user!.reports, 1);
    expect(events.events.first.reporterId, account.user!.uid);
    expect(events.events.first.speedLimit, 50);
  });

  test('Potwierdzanie zdarzeń przez użytkowników (bez podwójnego liczenia)',
      () async {
    SharedPreferences.setMockInitialValues({});
    final account = AccountProvider();
    await account.load();
    await account.quickSignIn(nickname: 'Kowal');
    final events = EventsProvider(account: account);

    final event = await events.addRoadEvent(
        type: RoadEventType.speedCameraMobile,
        location: const LatLng(52.1, 21.0));

    final first = await events.confirmRoadEvent(event.id);
    expect(first, ConfirmResult.ok);
    expect(events.events.first.confirmations, 1);

    final second = await events.confirmRoadEvent(event.id);
    expect(second, ConfirmResult.already);
    expect(events.events.first.confirmations, 1);

    expect(account.user!.confirmations, 1);
    expect(account.user!.points, PointsRules.report + PointsRules.confirmation);

    // Potwierdzenie innego użytkownika zwiększa licznik.
    final other = AccountProvider();
    await other.load();
    await other.quickSignIn(nickname: 'Zosia');
    final eventsOther = EventsProvider(account: other);
    await eventsOther.load();
    final res = await eventsOther.confirmRoadEvent(event.id);
    expect(res, ConfirmResult.ok);
    expect(eventsOther.events.first.confirmations, 2);
  });

  test('Gość nie może potwierdzać zdarzeń', () async {
    SharedPreferences.setMockInitialValues({});
    final account = AccountProvider();
    await account.load();
    final events = EventsProvider(account: account);
    final event = await events.addRoadEvent(
        type: RoadEventType.obstacle, location: const LatLng(52.0, 21.0));
    final result = await events.confirmRoadEvent(event.id);
    expect(result, ConfirmResult.notSignedIn);
  });

  test('Poziomy i postęp zależą od liczby punktów', () {
    expect(PointsRules.levelForPoints(0), 1);
    expect(PointsRules.levelForPoints(49), 1);
    expect(PointsRules.levelForPoints(50), 2);
    expect(PointsRules.levelForPoints(150), 3);
    expect(PointsRules.levelForPoints(10), 1);
    expect(PointsRules.levelName(2), 'Kierowca');
    expect(PointsRules.pointsForNextLevel(10), 50);
    expect(PointsRules.pointsForNextLevel(5000), isNull);
    expect(PointsRules.progressToNextLevel(0), 0);
    expect(PointsRules.progressToNextLevel(25), closeTo(0.5, 0.01));
    expect(PointsRules.progressToNextLevel(5000), 1.0);
  });
}

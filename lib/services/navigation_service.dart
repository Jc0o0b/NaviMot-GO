import '../models/road_event.dart';
import '../models/route_step.dart';

class NavigationService {
  static final NavigationService _instance = NavigationService._();
  static NavigationService get shared => _instance;
  NavigationService._();

  String instructionFor(RouteStep step) {
    return _verbFor(step);
  }

  /// Komunikat głosowy o nadjeżdżającym zdarzeniu na drodze,
  /// np. "Za 500 m fotoradar" albo "Za 1000 m kontrola zgłoszona przez
  /// użytkownika".
  String alertFor(RoadEvent event, int meters) {
    final m = meters < 100 ? 100 : meters;
    return 'Za $m m ${_eventPhrase(event.type)}';
  }

  String _eventPhrase(RoadEventType type) {
    switch (type) {
      case RoadEventType.police:
        return 'kontrola zgłoszona przez użytkownika';
      case RoadEventType.speedCamera:
        return 'fotoradar';
      case RoadEventType.accident:
        return 'wypadek na drodze';
      case RoadEventType.obstacle:
        return 'przedmiot na drodze';
      case RoadEventType.breakdown:
        return 'awaria pojazdu';
    }
  }

  bool shouldSpeak(RouteStep step) {
    switch (step.type) {
      case 'continue':
      case 'new name':
      case 'restricted':
        return false;
      default:
        return true;
    }
  }

  String _verbFor(RouteStep step) {
    final modifier = step.modifier ?? '';
    switch (step.type) {
      case 'depart':
        return 'Ruszaj przed siebie';
      case 'arrive':
        return 'Dotarłeś do celu';
      case 'turn':
      case 'end of road':
        return _turnVerb(modifier);
      case 'new name':
      case 'continue':
        return 'Jedź prosto';
      case 'merge':
        return 'Włącz się do ruchu';
      case 'on ramp':
        return 'Wjedź na drogę szybkiego ruchu';
      case 'off ramp':
        return 'Zjedź z drogi szybkiego ruchu';
      case 'fork':
        return modifier.contains('left')
            ? 'Trzymaj się lewej'
            : modifier.contains('right')
                ? 'Trzymaj się prawej'
                : 'Wybierz właściwą drogę';
      case 'roundabout':
      case 'rotary':
      case 'exit roundabout':
        return 'Na rondzie zjedź wyjazdem';
      case 'restricted':
        return 'Droga zastrzeżona';
      default:
        return 'Jedź prosto';
    }
  }

  String _turnVerb(String modifier) {
    switch (modifier) {
      case 'left':
        return 'Skręć w lewo';
      case 'right':
        return 'Skręć w prawo';
      case 'slight left':
        return 'Skręć w lewo';
      case 'slight right':
        return 'Skręć w prawo';
      case 'sharp left':
        return 'Ostro skręć w lewo';
      case 'sharp right':
        return 'Ostro skręć w prawo';
      case 'straight':
        return 'Jedź prosto';
      case 'uturn':
        return 'Zawróć';
      default:
        return 'Skręć';
    }
  }
}

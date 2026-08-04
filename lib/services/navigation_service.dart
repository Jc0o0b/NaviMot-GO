import '../models/route_step.dart';

class NavigationService {
  static final NavigationService _instance = NavigationService._();
  static NavigationService get shared => _instance;
  NavigationService._();

  String instructionFor(RouteStep step) {
    return _verbFor(step);
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

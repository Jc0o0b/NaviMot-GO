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
        return _turnVerb(modifier, step.name, endOfRoad: step.type == 'end of road');
      case 'new name':
        return 'Jedź dalej prosto${_roadSuffix(step.name)}';
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
            ? 'Trzymaj się lewej strony'
            : modifier.contains('right')
                ? 'Trzymaj się prawej strony'
                : 'Wybierz właściwą drogę';
      case 'roundabout':
      case 'rotary':
      case 'exit roundabout':
        return 'Na rondzie zjedź właściwym wyjazdem';
      case 'restricted':
        return 'Uwaga, droga zastrzeżona';
      default:
        return 'Jedź prosto';
    }
  }

  String _turnVerb(String modifier, String name, {bool endOfRoad = false}) {
    final road = _roadSuffix(name);
    final endPart = endOfRoad ? 'na końcu drogi ' : '';
    switch (modifier) {
      case 'left':
        return '${endPart}skręć w lewo$road';
      case 'right':
        return '${endPart}skręć w prawo$road';
      case 'slight left':
        return '${endPart}delikatnie skręć w lewo$road';
      case 'slight right':
        return '${endPart}delikatnie skręć w prawo$road';
      case 'sharp left':
        return '${endPart}ostro skręć w lewo$road';
      case 'sharp right':
        return '${endPart}ostro skręć w prawo$road';
      case 'straight':
        return 'Jedź prosto';
      case 'uturn':
        return 'Zawróć';
      default:
        return '${endPart}skręć$road';
    }
  }

  String _roadSuffix(String name) {
    if (name.isEmpty) return '';
    return ' w ulicę $name';
  }
}

import 'package:latlong2/latlong.dart';
import '../models/country.dart';

/// Wykrywanie krajów, przez które przebiega trasa, oraz punktów objazdu
/// wokół wybranego kraju (przybliżone granice jako prostokąty).
class CountryDetector {
  static final CountryDetector shared = CountryDetector._();
  CountryDetector._();

  /// Kod kraju, w którym znajduje się punkt (null, jeśli poza znanymi krajami).
  String? countryAt(LatLng p) {
    Country? best;
    for (final c in Country.all) {
      if (c.contains(p)) {
        if (best == null || c.bounds.area < best.bounds.area) best = c;
      }
    }
    return best?.code;
  }

  List<String> countriesAlong(List<LatLng> waypoints) {
    final codes = <String>{};
    for (final p in waypoints) {
      final c = countryAt(p);
      if (c != null) codes.add(c);
    }
    return codes.toList();
  }

  bool crosses(List<LatLng> waypoints, String countryCode) =>
      countriesAlong(waypoints).contains(countryCode);

  /// Zwraca dwa punkty "za rogiem" powiększonego prostokąta kraju, tak aby
  /// trasa poprowadzona przez nie ominęła dany kraj. Null, gdy ominięcie
  /// nie jest możliwe (start/cel w kraju lub trasa nie przechodzi przez kraj).
  List<LatLng>? computeDetourPoints(
      List<LatLng> waypoints, Country country) {
    if (waypoints.length < 2) return null;
    final b = country.bounds.inflated(0.3);
    if (b.contains(waypoints.first) || b.contains(waypoints.last)) return null;

    var inside = false;
    for (final p in waypoints) {
      if (b.contains(p)) {
        inside = true;
        break;
      }
    }
    if (!inside) return null;

    final corners = [b.northEast, b.northWest, b.southWest, b.southEast];
    final mid = waypoints[waypoints.length ~/ 2];

    var farIdx = 0;
    var farDist = -1.0;
    for (var i = 0; i < corners.length; i++) {
      final d = _sqDist(corners[i], mid);
      if (d > farDist) {
        farDist = d;
        farIdx = i;
      }
    }

    final n1 = (farIdx + 1) % 4;
    final n2 = (farIdx + 3) % 4;
    final neighbor =
        _sqDist(corners[n1], mid) >= _sqDist(corners[n2], mid) ? n1 : n2;

    return [corners[farIdx], corners[neighbor]];
  }

  double _sqDist(LatLng a, LatLng b) {
    final dLat = a.latitude - b.latitude;
    final dLon = a.longitude - b.longitude;
    return dLat * dLat + dLon * dLon;
  }
}

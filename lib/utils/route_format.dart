/// Wspólne formatowanie czasu i dystansu.
///
/// Wcześniej ta logika była zduplikowana w czterech miejscach
/// (map_screen, navigation_screen, routing_service, saved_routes_screen).
class RouteFormat {
  RouteFormat._();

  /// 840 → "840 m", 1250 → "1,3 km", 235679 → "236 km"
  static String distance(double meters) {
    if (meters < 0) return '0 m';
    if (meters < 950) return '${meters.round()} m';
    final km = meters / 1000.0;
    return km >= 100 ? '${km.round()} km' : '${km.toStringAsFixed(1)} km';
  }

  /// Krótsze warianty do niewielkich odległości w instrukcjach nawigacji.
  static String shortDistance(double meters) {
    if (meters < 0) return '0 m';
    if (meters < 950) return '${meters.round()} m';
    final km = meters / 1000.0;
    if (km >= 100) return '${km.round()} km';
    return '${km.toStringAsFixed(1)} km';
  }

  /// 90 → "1 min", 4500 → "1 h 15 min"
  static String duration(int seconds) {
    if (seconds < 0) return '0 min';
    final min = (seconds / 60).round();
    if (min < 60) return '$min min';
    final h = min ~/ 60;
    final m = min % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }

  static String durationFromMinutes(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }

  /// Zwięzły wariant: 4500 → "1h 15min", 900 → "15 min".
  static String durationCompact(int seconds) {
    if (seconds < 0) return '0 min';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return h > 0 ? '${h}h ${m}min' : '$m min';
  }
}

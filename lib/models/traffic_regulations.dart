import 'route.dart';

class PolishTrafficRegulations {
  static final PolishTrafficRegulations _instance = PolishTrafficRegulations._();
  static PolishTrafficRegulations get shared => _instance;
  PolishTrafficRegulations._();

  static const int builtUpAreaLimit = 50;
  static const int builtUpAreaLimitNight = 60;

  int speedLimitFor(RoadType roadType, {bool isNight = false, bool isMotorcycle = true}) {
    switch (roadType) {
      case RoadType.highway: return 140;
      case RoadType.expressway: return 120;
      case RoadType.national: return 100;
      case RoadType.regional: return 90;
      case RoadType.local: return 90;
      case RoadType.scenic: return 90;
      case RoadType.unpaved: return 30;
    }
  }

  double estimatedTravelTime(double distanceMeters, RoadType roadType, {bool includeBreaks = true}) {
    final limit = speedLimitFor(roadType).toDouble();
    final hours = (distanceMeters / 1000.0) / limit;
    var seconds = hours * 3600.0;

    if (includeBreaks) {
      final breaks = (hours / 2.0).floor().clamp(0, 100);
      seconds += breaks * 15 * 60.0;
    }

    return seconds;
  }

  TravelTimeInfo calculateTravelTime(double totalDistance, List<RoadType> roadTypes) {
    final distanceKm = totalDistance / 1000.0;
    final types = roadTypes.isNotEmpty ? roadTypes : [RoadType.national];

    var drivingSeconds = 0.0;
    for (final type in types) {
      final limit = speedLimitFor(type).toDouble();
      final avgSpeed = limit * 0.9;
      final segmentDistance = distanceKm / types.length;
      drivingSeconds += (segmentDistance / avgSpeed) * 3600.0;
    }

    final hours = drivingSeconds / 3600.0;
    final breakMinutes = hours.floor().clamp(0, 100) * 10;
    final breakSeconds = breakMinutes * 60.0;

    return TravelTimeInfo(
      drivingTime: drivingSeconds,
      totalTime: drivingSeconds + breakSeconds,
      breakTime: breakSeconds,
      averageSpeed: distanceKm / (drivingSeconds / 3600.0),
      distance: totalDistance,
    );
  }
}

class TravelTimeInfo {
  final double drivingTime;
  final double totalTime;
  final double breakTime;
  final double averageSpeed;
  final double distance;

  TravelTimeInfo({
    required this.drivingTime,
    required this.totalTime,
    required this.breakTime,
    required this.averageSpeed,
    required this.distance,
  });

  String get formattedDrivingTime => _formatTime(drivingTime);
  String get formattedTotalTime => _formatTime(totalTime);
  String get formattedDistance {
    final km = distance / 1000.0;
    return km >= 100 ? '${km.toInt()} km' : '${km.toStringAsFixed(1)} km';
  }
  String get formattedSpeed => '${averageSpeed.toInt()} km/h';

  String _formatTime(double seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}min';
    return '${m} min';
  }
}

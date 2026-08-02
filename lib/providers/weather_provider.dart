import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/route.dart';
import '../models/weather_point.dart';
import '../services/weather_service.dart';

class WeatherProvider extends ChangeNotifier {
  List<WeatherPoint> _weatherPoints = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<WeatherPoint> get weatherPoints => _weatherPoints;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void loadWeather(MotorcycleRoute route) {
    if (route.waypoints.isEmpty) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    WeatherService.shared.fetchWeatherAlongRoute(route.waypoints).then((points) {
      _weatherPoints = points;
      _isLoading = false;
      notifyListeners();
    }).catchError((e) {
      _errorMessage = 'Nie udało się pobrać pogody: $e';
      _isLoading = false;
      notifyListeners();
    });
  }

  WeatherPoint? weatherAtCoordinate(LatLng coordinate) {
    if (_weatherPoints.isEmpty) return null;
    WeatherPoint? closest;
    double minDist = double.infinity;
    for (final wp in _weatherPoints) {
      final d = _distanceBetween(wp.coordinate, coordinate);
      if (d < minDist) {
        minDist = d;
        closest = wp;
      }
    }
    return closest;
  }

  WeatherCondition get predominantCondition {
    if (_weatherPoints.isEmpty) return WeatherCondition.sunny;
    final counts = <WeatherCondition, int>{};
    for (final wp in _weatherPoints) {
      counts[wp.condition] = (counts[wp.condition] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  double get averageTemperature {
    if (_weatherPoints.isEmpty) return 0;
    return _weatherPoints.fold(0.0, (sum, wp) => sum + wp.temperature) / _weatherPoints.length;
  }

  double get maxWindSpeed {
    if (_weatherPoints.isEmpty) return 0;
    return _weatherPoints.map((wp) => wp.windSpeed).reduce((a, b) => a > b ? a : b);
  }

  double get maxPrecipitationProbability {
    if (_weatherPoints.isEmpty) return 0;
    return _weatherPoints.map((wp) => wp.precipitationProbability).reduce((a, b) => a > b ? a : b);
  }

  bool get hasRiskyWeather => _weatherPoints.any((wp) =>
    wp.condition == WeatherCondition.thunderstorm ||
    wp.condition == WeatherCondition.heavyRain ||
    wp.condition == WeatherCondition.snow);

  String? get weatherAlert {
    if (hasRiskyWeather) return '⚠️ Na trasie występują niebezpieczne warunki pogodowe';
    if (maxWindSpeed > 50) return '💨 Silny wiatr na trasie (${maxWindSpeed.toInt()} km/h)';
    if (maxPrecipitationProbability > 70) return '🌧️ Wysokie prawdopodobieństwo opadów (${maxPrecipitationProbability.toInt()}%)';
    return null;
  }

  double _distanceBetween(LatLng a, LatLng b) {
    final dx = a.latitude - b.latitude;
    final dy = a.longitude - b.longitude;
    return dx * dx + dy * dy;
  }
}

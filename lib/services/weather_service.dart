import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/weather_point.dart';
import '../utils/route_scaling.dart';

class WeatherService {
  static final WeatherService _instance = WeatherService._();
  static WeatherService get shared => _instance;
  WeatherService._();

  final String _baseUrl = 'https://api.open-meteo.com/v1/forecast';
  final http.Client _client = http.Client();

  Future<List<WeatherPoint>> fetchWeatherAlongRoute(
    List<LatLng> waypoints, {
    DateTime? startTime,
  }) async {
    final sampled = _samplePoints(waypoints, markerCountForRoute(waypoints));
    final points = <WeatherPoint>[];
    if (sampled.isEmpty) return points;
    startTime ??= DateTime.now();

    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'latitude': sampled.map((p) => p.latitude.toStringAsFixed(4)).join(','),
        'longitude': sampled.map((p) => p.longitude.toStringAsFixed(4)).join(','),
        'hourly': 'temperature_2m,weather_code,precipitation_probability,wind_speed_10m',
        'timezone': 'Europe/Warsaw',
        'forecast_days': '3',
      });

      final response = await _client.get(uri);
      if (response.statusCode != 200) return points;

      final decoded = jsonDecode(response.body);
      final forecasts = decoded is List ? decoded : [decoded];

      for (var i = 0; i < sampled.length && i < forecasts.length; i++) {
        final forecast = forecasts[i] as Map<String, dynamic>;
        final hourly = forecast['hourly'] as Map<String, dynamic>? ?? {};
        final times = hourly['time'] as List? ?? [];
        final temps = hourly['temperature_2m'] as List? ?? [];
        final codes = hourly['weather_code'] as List? ?? [];
        final precips = hourly['precipitation_probability'] as List? ?? [];
        final winds = hourly['wind_speed_10m'] as List? ?? [];

        final idx = _nearestHourIndex(times, startTime.hour);
        if (idx == null) continue;
        points.add(WeatherPoint(
          coordinate: sampled[i],
          temperature: _numAt(temps, idx, 0.0),
          condition: _mapWeatherCode(_numAt(codes, idx, 0).round()),
          precipitationProbability: _numAt(precips, idx, 0.0),
          windSpeed: _numAt(winds, idx, 0.0),
        ));
      }
    } catch (_) {}

    return points;
  }

  int? _nearestHourIndex(List<dynamic> times, int targetHour) {
    for (var i = 0; i < times.length; i++) {
      final t = times[i];
      if (t is! String) continue;
      final parts = t.split('T');
      if (parts.length < 2) continue;
      final hour = int.tryParse(parts[1].split(':')[0]);
      if (hour != null && hour >= targetHour) return i;
    }
    return null;
  }

  double _numAt(List<dynamic> list, int index, double fallback) {
    if (index >= list.length) return fallback;
    final v = list[index];
    return v is num ? v.toDouble() : fallback;
  }

  List<LatLng> _samplePoints(List<LatLng> waypoints, int count) {
    if (waypoints.length <= count) return waypoints;
    final sampled = <LatLng>[];
    final interval = waypoints.length / count;
    for (var i = 0; i < count; i++) {
      sampled.add(waypoints[(i * interval).round().clamp(0, waypoints.length - 1)]);
    }
    return sampled;
  }

  WeatherCondition _mapWeatherCode(int code) {
    switch (code) {
      case 0: return WeatherCondition.sunny;
      case 1: case 2: return WeatherCondition.partlyCloudy;
      case 3: return WeatherCondition.cloudy;
      case 45: case 48: return WeatherCondition.fog;
      case 51: case 53: case 55: case 56: case 57:
      case 61: case 63: case 65: return WeatherCondition.rain;
      case 66: case 67: case 80: case 81: case 82: return WeatherCondition.heavyRain;
      case 71: case 73: case 75: case 77: case 85: case 86: return WeatherCondition.snow;
      case 95: case 96: case 99: return WeatherCondition.thunderstorm;
      default: return WeatherCondition.partlyCloudy;
    }
  }

  void dispose() => _client.close();
}

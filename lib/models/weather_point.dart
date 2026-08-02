import 'package:latlong2/latlong.dart';

class WeatherPoint {
  final LatLng coordinate;
  final double temperature;
  final WeatherCondition condition;
  final double windSpeed;
  final double precipitationProbability;

  WeatherPoint({
    required this.coordinate,
    required this.temperature,
    required this.condition,
    required this.windSpeed,
    required this.precipitationProbability,
  });

  String get iconName {
    switch (condition) {
      case WeatherCondition.sunny: return 'sunny';
      case WeatherCondition.partlyCloudy: return 'partly_cloudy';
      case WeatherCondition.cloudy: return 'cloudy';
      case WeatherCondition.rain: return 'rain';
      case WeatherCondition.heavyRain: return 'heavy_rain';
      case WeatherCondition.thunderstorm: return 'thunderstorm';
      case WeatherCondition.snow: return 'snow';
      case WeatherCondition.fog: return 'fog';
      case WeatherCondition.windy: return 'windy';
    }
  }
}

enum WeatherCondition {
  sunny,
  partlyCloudy,
  cloudy,
  rain,
  heavyRain,
  thunderstorm,
  snow,
  fog,
  windy;
}

class WeatherForecast {
  final HourlyData hourly;
  final DailyData daily;

  WeatherForecast({required this.hourly, required this.daily});

  factory WeatherForecast.fromJson(Map<String, dynamic> json) {
    return WeatherForecast(
      hourly: HourlyData.fromJson(json['hourly']),
      daily: DailyData.fromJson(json['daily']),
    );
  }
}

class HourlyData {
  final List<String> time;
  final List<double> temperature2m;
  final List<int> weatherCode;
  final List<double> precipitationProbability;
  final List<double> windSpeed10m;

  HourlyData({
    required this.time,
    required this.temperature2m,
    required this.weatherCode,
    required this.precipitationProbability,
    required this.windSpeed10m,
  });

  factory HourlyData.fromJson(Map<String, dynamic> json) {
    return HourlyData(
      time: List<String>.from(json['time'] ?? []),
      temperature2m: List<double>.from(json['temperature_2m']?.map((x) => (x as num).toDouble()) ?? []),
      weatherCode: List<int>.from(json['weather_code']?.map((x) => (x as num).toInt()) ?? []),
      precipitationProbability: List<double>.from(json['precipitation_probability']?.map((x) => (x as num).toDouble()) ?? []),
      windSpeed10m: List<double>.from(json['wind_speed_10m']?.map((x) => (x as num).toDouble()) ?? []),
    );
  }
}

class DailyData {
  final List<String> time;
  final List<int> weatherCode;
  final List<double> temperature2mMax;
  final List<double> temperature2mMin;
  final List<double> precipitationProbabilityMax;

  DailyData({
    required this.time,
    required this.weatherCode,
    required this.temperature2mMax,
    required this.temperature2mMin,
    required this.precipitationProbabilityMax,
  });

  factory DailyData.fromJson(Map<String, dynamic> json) {
    return DailyData(
      time: List<String>.from(json['time'] ?? []),
      weatherCode: List<int>.from(json['weather_code']?.map((x) => (x as num).toInt()) ?? []),
      temperature2mMax: List<double>.from(json['temperature_2m_max']?.map((x) => (x as num).toDouble()) ?? []),
      temperature2mMin: List<double>.from(json['temperature_2m_min']?.map((x) => (x as num).toDouble()) ?? []),
      precipitationProbabilityMax: List<double>.from(json['precipitation_probability_max']?.map((x) => (x as num).toDouble()) ?? []),
    );
  }
}

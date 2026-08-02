import 'package:flutter/material.dart';
import '../models/weather_point.dart';

class WeatherIconWidget extends StatelessWidget {
  final WeatherPoint point;
  const WeatherIconWidget({super.key, required this.point});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 2)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon(), size: 18, color: _color()),
          Text('${point.temperature.toInt()}°',
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  IconData _icon() {
    switch (point.condition) {
      case WeatherCondition.sunny: return Icons.wb_sunny;
      case WeatherCondition.partlyCloudy: return Icons.cloud;
      case WeatherCondition.cloudy: return Icons.cloud;
      case WeatherCondition.rain: return Icons.water;
      case WeatherCondition.heavyRain: return Icons.thunderstorm;
      case WeatherCondition.thunderstorm: return Icons.flash_on;
      case WeatherCondition.snow: return Icons.ac_unit;
      case WeatherCondition.fog: return Icons.foggy;
      case WeatherCondition.windy: return Icons.air;
    }
  }

  Color _color() {
    switch (point.condition) {
      case WeatherCondition.sunny: return Colors.yellow;
      case WeatherCondition.partlyCloudy: return Colors.orange;
      case WeatherCondition.cloudy: return Colors.grey;
      case WeatherCondition.rain: return Colors.blue;
      case WeatherCondition.heavyRain: return Colors.indigo;
      case WeatherCondition.thunderstorm: return Colors.purple;
      case WeatherCondition.snow: return Colors.cyan;
      case WeatherCondition.fog: return Colors.grey;
      case WeatherCondition.windy: return Colors.teal;
    }
  }
}

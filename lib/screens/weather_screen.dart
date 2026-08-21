import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/weather_point.dart';
import '../providers/weather_provider.dart';
import '../providers/route_provider.dart';
import '../widgets/section_header.dart';

class WeatherScreen extends StatelessWidget {
  const WeatherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<WeatherProvider, RouteProvider>(
      builder: (context, weatherVM, routeVM, _) {
        final hasRoute = routeVM.currentRoute != null;

        return Scaffold(
          body: Column(
            children: [
              const SectionHeader(title: 'Pogoda na trasie', icon: Icons.cloud),
              Expanded(
                child: hasRoute && weatherVM.weatherPoints.isNotEmpty
                    ? _buildWeatherContent(context, weatherVM)
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_off,
                                size: 64, color: Colors.grey[600]),
                            const SizedBox(height: 16),
                            Text(
                              hasRoute
                                  ? 'Brak danych pogodowych'
                                  : 'Wyznacz trasę, aby zobaczyć pogodę',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWeatherContent(BuildContext context, WeatherProvider weatherVM) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSummaryCard(context, weatherVM),
        const SizedBox(height: 16),
        const Text('Prognoza na trasie',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: weatherVM.weatherPoints.length,
            itemBuilder: (_, i) =>
                _buildWeatherCard(weatherVM.weatherPoints[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(BuildContext context, WeatherProvider weatherVM) {
    final condition = weatherVM.predominantCondition;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(_weatherIcon(condition),
                size: 64, color: _weatherColor(condition)),
            const SizedBox(height: 8),
            Text('${weatherVM.averageTemperature.toInt()}°C',
                style: TextStyle(
                    fontSize: MediaQuery.sizeOf(context).width < 360 ? 28 : 36,
                    fontWeight: FontWeight.bold)),
            Text(_conditionName(condition),
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStat(Icons.air, '${weatherVM.maxWindSpeed.toInt()} km/h',
                    'Wiatr'),
                _buildStat(
                    Icons.water_drop,
                    '${weatherVM.maxPrecipitationProbability.toInt()}%',
                    'Opady'),
                _buildStat(Icons.location_on,
                    '${weatherVM.weatherPoints.length}', 'Punkty'),
              ],
            ),
            if (weatherVM.weatherAlert != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: weatherVM.hasRiskyWeather
                      ? Colors.red.withOpacity(0.2)
                      : Colors.yellow.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      weatherVM.hasRiskyWeather ? Icons.warning : Icons.info,
                      color: weatherVM.hasRiskyWeather
                          ? Colors.red
                          : Colors.yellow,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(weatherVM.weatherAlert!,
                            style: const TextStyle(fontSize: 12))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherCard(WeatherPoint wp) {
    return Card(
      margin: const EdgeInsets.only(right: 8),
      child: Container(
        width: 80,
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${wp.temperature.toInt()}°',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Icon(_weatherIcon(wp.condition),
                color: _weatherColor(wp.condition), size: 24),
            const SizedBox(height: 4),
            Text('${wp.windSpeed.toInt()} km/h',
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.orange, size: 20),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  IconData _weatherIcon(WeatherCondition c) {
    switch (c) {
      case WeatherCondition.sunny:
        return Icons.wb_sunny;
      case WeatherCondition.partlyCloudy:
        return Icons.cloud;
      case WeatherCondition.cloudy:
        return Icons.cloud;
      case WeatherCondition.rain:
        return Icons.water;
      case WeatherCondition.heavyRain:
        return Icons.thunderstorm;
      case WeatherCondition.thunderstorm:
        return Icons.flash_on;
      case WeatherCondition.snow:
        return Icons.ac_unit;
      case WeatherCondition.fog:
        return Icons.foggy;
      case WeatherCondition.windy:
        return Icons.air;
    }
  }

  Color _weatherColor(WeatherCondition c) {
    switch (c) {
      case WeatherCondition.sunny:
        return Colors.yellow;
      case WeatherCondition.partlyCloudy:
        return Colors.orange;
      case WeatherCondition.cloudy:
        return Colors.grey;
      case WeatherCondition.rain:
        return Colors.blue;
      case WeatherCondition.heavyRain:
        return Colors.indigo;
      case WeatherCondition.thunderstorm:
        return Colors.purple;
      case WeatherCondition.snow:
        return Colors.cyan;
      case WeatherCondition.fog:
        return Colors.grey;
      case WeatherCondition.windy:
        return Colors.teal;
    }
  }

  String _conditionName(WeatherCondition c) {
    switch (c) {
      case WeatherCondition.sunny:
        return 'Słonecznie';
      case WeatherCondition.partlyCloudy:
        return 'Częściowe zachmurzenie';
      case WeatherCondition.cloudy:
        return 'Pochmurno';
      case WeatherCondition.rain:
        return 'Deszcz';
      case WeatherCondition.heavyRain:
        return 'Ulewa';
      case WeatherCondition.thunderstorm:
        return 'Burza';
      case WeatherCondition.snow:
        return 'Śnieg';
      case WeatherCondition.fog:
        return 'Mgła';
      case WeatherCondition.windy:
        return 'Wietrznie';
    }
  }
}

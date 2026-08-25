import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/route.dart';
import '../models/traffic_regulations.dart';
import '../providers/events_provider.dart';
import '../providers/route_provider.dart';
import '../providers/weather_provider.dart';
import '../providers/poi_provider.dart';
import '../utils/gmx_download.dart';
import '../widgets/offline_route_preview.dart';
import '../widgets/section_header.dart';

class SavedRoutesScreen extends StatelessWidget {
  const SavedRoutesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RouteProvider>(
      builder: (context, routeVM, _) {
        return Scaffold(
          body: Column(
            children: [
              SectionHeader(
                title: 'Zapisane trasy',
                icon: Icons.bookmark,
              ),
              Expanded(
                child: routeVM.savedRoutes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bookmark_border,
                                size: 64, color: Colors.grey[600]),
                            const SizedBox(height: 16),
                            Text('Brak zapisanych tras',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            const Text(
                                'Zaplanuj i zapisz trasę, aby ją tutaj zobaczyć',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: routeVM.savedRoutes.length,
                        itemBuilder: (_, i) => _buildRouteCard(
                            context, routeVM, routeVM.savedRoutes[i]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRouteCard(
      BuildContext context, RouteProvider routeVM, MotorcycleRoute route) {
    final scenicColor = route.scenicScore >= 60
        ? Colors.green
        : route.scenicScore >= 30
            ? Colors.orange
            : Colors.grey;

    final travelTime = PolishTrafficRegulations.shared
        .calculateTravelTime(route.totalDistance, route.roadTypes)
        .drivingTime;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: scenicColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.route, color: scenicColor),
        ),
        title: Text(route.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.straighten, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(_formatDistance(route.totalDistance),
                    style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 12),
                const Icon(Icons.schedule, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(_formatDuration(travelTime),
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
            if (route.roadTypes.isNotEmpty)
              Text(route.roadTypes.map((t) => t.label).join(', '),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Udostępnij trasę (GPX)',
              icon: const Icon(Icons.ios_share, size: 20),
              onPressed: () => _exportRoute(context, route),
            ),
            IconButton(
              tooltip: 'Usuń trasę',
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => _confirmDelete(context, routeVM, route),
            ),
          ],
        ),
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _RouteDetailScreen(route: route),
            )),
      ),
    );
  }

  Future<void> _exportRoute(
      BuildContext context, MotorcycleRoute route) async {
    final choice = await showModalBottomSheet<_GmxExportAction>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Udostępnij trasę „${route.name}"'),
              subtitle: const Text('Wybierz sposób udostępnienia pliku GPX'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.link, color: Colors.deepOrange),
              title: const Text('Kopiuj link do trasy'),
              subtitle: const Text('Odbiorca otworzy link w przeglądarce'),
              onTap: () => Navigator.of(ctx).pop(_GmxExportAction.link),
            ),
            ListTile(
              leading: const Icon(Icons.download, color: Colors.deepOrange),
              title: const Text('Pobierz plik .gpx'),
              subtitle: const Text('Zapisz plik i wyślij go np. e-mailem'),
              onTap: () => Navigator.of(ctx).pop(_GmxExportAction.file),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    switch (choice) {
      case _GmxExportAction.link:
        await copyGmxLink(route);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Link do trasy GPX skopiowany do schowka')),
        );
      case _GmxExportAction.file:
        downloadGmx(route);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pobrano plik GPX: ${route.name}.gpx')),
        );
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, RouteProvider routeVM, MotorcycleRoute route) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usunąć trasę?'),
        content: Text('Czy na pewno chcesz usunąć trasę „${route.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    if (ok == true) {
      routeVM.deleteRoute(route);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trasa została usunięta')),
      );
    }
  }

  String _formatDistance(double meters) {
    final km = meters / 1000.0;
    return km >= 100 ? '${km.toInt()} km' : '${km.toStringAsFixed(1)} km';
  }

  String _formatDuration(double seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return h > 0 ? '${h}h ${m}min' : '${m} min';
  }
}

enum _GmxExportAction { link, file }

class _RouteDetailScreen extends StatefulWidget {
  final MotorcycleRoute route;
  const _RouteDetailScreen({required this.route});

  @override
  State<_RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<_RouteDetailScreen> {
  @override
  void initState() {
    super.initState();
    final weatherVM = context.read<WeatherProvider>();
    final poiVM = context.read<POIProvider>();
    weatherVM.loadWeather(widget.route);
    poiVM.loadPOIs(widget.route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.route.name)),
      body: Consumer2<WeatherProvider, POIProvider>(
        builder: (context, weatherVM, poiVM, _) {
          final eventsVM = context.watch<EventsProvider>();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Offline preview (bez kafli mapy - działa bez internetu)
              SizedBox(
                height: 200,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    OfflineRoutePreview(
                      route: widget.route,
                      events: eventsVM.events,
                      places: eventsVM.importantPlaces,
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_off,
                                size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text('Dostępne offline',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Stats
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Szczegóły trasy',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _statBox(
                              Icons.straighten,
                              _formatDistance(widget.route.totalDistance),
                              'Dystans'),
                          const SizedBox(width: 8),
                          _statBox(
                              Icons.schedule,
                              _formatDuration(
                                  PolishTrafficRegulations.shared
                                      .calculateTravelTime(
                                          widget.route.totalDistance,
                                          widget.route.roadTypes)
                                      .drivingTime),
                              'Czas'),
                        ],
                      ),
                      if (widget.route.roadTypes.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text('Rodzaje dróg:',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ...widget.route.roadTypes.map((t) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(t.label,
                                  style: const TextStyle(fontSize: 12)),
                            )),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Weather
              if (weatherVM.weatherPoints.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Pogoda na trasie',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 60,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: weatherVM.weatherPoints
                                .map((wp) => Container(
                                      width: 50,
                                      margin: const EdgeInsets.only(right: 4),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.wb_sunny,
                                              size: 16, color: Colors.yellow),
                                          Text('${wp.temperature.toInt()}°',
                                              style: const TextStyle(
                                                  fontSize: 10)),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // POIs
              if (poiVM.pointsOfInterest.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Miejsca do odwiedzenia',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ...poiVM.pointsOfInterest.take(5).map((poi) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.pin_drop,
                                      size: 16, color: Colors.orange),
                                  const SizedBox(width: 8),
                                  Text(poi.name,
                                      style: const TextStyle(fontSize: 13)),
                                  const Spacer(),
                                  Text(poi.category.label,
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _statBox(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.orange, size: 20),
            const SizedBox(height: 4),
            Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  String _formatDistance(double meters) {
    final km = meters / 1000.0;
    return km >= 100 ? '${km.toInt()} km' : '${km.toStringAsFixed(1)} km';
  }

  String _formatDuration(double seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return h > 0 ? '${h}h ${m}min' : '${m} min';
  }
}

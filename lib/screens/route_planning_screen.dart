import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/home_address.dart';
import '../models/point_of_interest.dart';
import '../models/route.dart';
import '../providers/poi_provider.dart';
import '../providers/route_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/weather_provider.dart';
import '../services/geocoding_service.dart';
import 'navigation_screen.dart';

class RoutePlanningScreen extends StatefulWidget {
  final VoidCallback? onRoutePlanned;
  const RoutePlanningScreen({super.key, this.onRoutePlanned});

  @override
  State<RoutePlanningScreen> createState() => _RoutePlanningScreenState();
}

class _RoutePlanningScreenState extends State<RoutePlanningScreen> {
  final _startController = TextEditingController();
  final _endController = TextEditingController();
  List<GeocodingResult> _startResults = [];
  List<GeocodingResult> _endResults = [];
  Timer? _debounce;
  int _searchSequence = 0;
  String? _loadedRouteId;
  bool _navigateOnReady = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<RouteProvider, WeatherProvider, POIProvider>(
      builder: (context, routeVM, weatherVM, poiVM, _) {
        final route = routeVM.currentRoute;
        if (route != null && route.id != _loadedRouteId) {
          _loadedRouteId = route.id;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            weatherVM.loadWeather(route);
            poiVM.loadPOIs(route);
            if (_navigateOnReady) {
              _navigateOnReady = false;
              widget.onRoutePlanned?.call();
            }
          });
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('Planowanie trasy'),
            centerTitle: true,
            actions: [
              IconButton(
                tooltip: 'Adres domowy',
                icon: const Icon(Icons.home_outlined),
                onPressed: _showHomeSheet,
              ),
              TextButton.icon(
                onPressed: () => routeVM.useCurrentLocation(),
                icon: const Icon(Icons.gps_fixed, size: 18),
                label: const Text('GPS'),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLocationField(
                  controller: _startController,
                  icon: Icons.motorcycle,
                  color: Colors.green,
                  hint: 'Wpisz miejsce startu...',
                  results: _startResults,
                  onSelected: (loc) {
                    _startController.text = loc.displayName;
                    routeVM.setStartLocation(LatLng(loc.lat, loc.lon));
                    _startResults = [];
                  },
                  onChanged: (q) => _searchLocation(q, (r) => _startResults = r),
                ),
                const SizedBox(height: 12),
                _buildLocationField(
                  controller: _endController,
                  icon: Icons.flag,
                  color: Colors.red,
                  hint: 'Wpisz miejsce docelowe...',
                  results: _endResults,
                  onSelected: (loc) {
                    _endController.text = loc.displayName;
                    routeVM.setEndLocation(LatLng(loc.lat, loc.lon));
                    _endResults = [];
                  },
                  onChanged: (q) => _searchLocation(q, (r) => _endResults = r),
                ),
                const SizedBox(height: 24),
                _buildOptions(routeVM),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: (routeVM.startLocation != null && routeVM.endLocation != null)
                      ? () {
                          setState(() => _navigateOnReady = true);
                          routeVM.planRoute(routeVM.startLocation!, routeVM.endLocation!);
                        }
                      : null,
                  icon: const Icon(Icons.route),
                  label: const Text('Wyznacz trasę'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                if (routeVM.isLoading) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ],
                if (routeVM.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(routeVM.errorMessage!, style: const TextStyle(color: Colors.red)),
                ],
                if (routeVM.currentRoute != null) ...[
                  const SizedBox(height: 24),
                  _buildConfirmation(routeVM),
                  if (routeVM.intermediateWaypoints.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: routeVM.intermediateWaypoints.map((w) => InputChip(
                        label: const Text('Punkt pośredni', style: TextStyle(fontSize: 12)),
                        onDeleted: () => routeVM.removeWaypoint(w),
                        deleteIconColor: Colors.red,
                      )).toList(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(height: 380, child: _buildPOIPanel(routeVM, poiVM)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLocationField({
    required TextEditingController controller,
    required IconData icon,
    required Color color,
    required String hint,
    required List<GeocodingResult> results,
    required Function(GeocodingResult) onSelected,
    required Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(hint, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () { controller.clear(); onChanged(''); },
            ),
          ),
          onChanged: (q) => _onSearchChanged(controller, q),
        ),
        if (results.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 150),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: results.length,
              itemBuilder: (_, i) => ListTile(
                dense: true,
                title: Text(results[i].displayName, style: const TextStyle(fontSize: 13)),
                subtitle: Text('${results[i].lat.toStringAsFixed(4)}, ${results[i].lon.toStringAsFixed(4)}',
                  style: const TextStyle(fontSize: 11)),
                onTap: () => onSelected(results[i]),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOptions(RouteProvider routeVM) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Preferencje trasy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Unikaj autostrad'),
              subtitle: const Text('Bardziej malownicze drogi'),
              value: routeVM.routeOptions.avoidHighways,
              onChanged: (v) { routeVM.routeOptions.avoidHighways = v; routeVM.setRouteOptions(routeVM.routeOptions); },
            ),
            SwitchListTile(
              title: const Text('Preferuj kręte drogi'),
              subtitle: const Text('Więcej zakrętów = więcej frajdy'),
              value: routeVM.routeOptions.preferCurvyRoads,
              onChanged: (v) { routeVM.routeOptions.preferCurvyRoads = v; routeVM.setRouteOptions(routeVM.routeOptions); },
            ),
            SwitchListTile(
              title: const Text('Dodaj malownicze objazdy'),
              subtitle: const Text('Odwiedź ciekawe miejsca po drodze'),
              value: routeVM.routeOptions.includeScenicDetours,
              onChanged: (v) { routeVM.routeOptions.includeScenicDetours = v; routeVM.setRouteOptions(routeVM.routeOptions); },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmation(RouteProvider routeVM) {
    final route = routeVM.currentRoute!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 22),
                const SizedBox(width: 8),
                const Text('Trasa wyznaczona!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text(route.name, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => NavigationScreen(route: route),
                    )),
                    icon: const Icon(Icons.navigation, size: 18),
                    label: const Text('Start'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => widget.onRoutePlanned?.call(),
                    icon: const Icon(Icons.map, size: 18),
                    label: const Text('Przejdź do mapy'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () => _saveRoute(context, routeVM, route),
              icon: const Icon(Icons.bookmark),
              label: const Text('Zapisz trasę'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ],
        ),
      ),
    );
  }

  void _saveRoute(BuildContext context, RouteProvider routeVM, MotorcycleRoute route) {
    final already = routeVM.savedRoutes.any((r) => r.id == route.id);
    if (!already) routeVM.saveRoute(route);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(already ? 'Trasa jest już w Zapisane' : 'Trasa zapisana w Zapisane'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildPOIPanel(RouteProvider routeVM, POIProvider poiVM) {
    final pois = poiVM.pointsOfInterest;
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                const Icon(Icons.attractions, color: Colors.orange, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Dla motocyklisty (10 km)', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
                if (poiVM.isLoading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          Expanded(
            child: poiVM.isLoading
                ? const Center(child: CircularProgressIndicator())
                : poiVM.errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cloud_off, color: Colors.grey, size: 28),
                              const SizedBox(height: 6),
                              Text(
                                'Nie udało się pobrać miejsc.\nSpróbuj ponownie później.',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : pois.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                'Brak miejsc w promieniu 10 km od trasy',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            itemCount: pois.take(15).length,
                            itemBuilder: (_, i) => _buildPOITile(routeVM, pois[i]),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildPOITile(RouteProvider routeVM, PointOfInterest poi) {
    final added = routeVM.intermediateWaypoints.any((w) =>
        (w.latitude - poi.coordinate.latitude).abs() < 0.0001 &&
        (w.longitude - poi.coordinate.longitude).abs() < 0.0001);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: Colors.orange.withValues(alpha: 0.2),
          child: Icon(_poiIcon(poi.category), color: Colors.orange, size: 18),
        ),
        title: Text(poi.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(poi.category.label, style: const TextStyle(fontSize: 11)),
        trailing: IconButton(
          tooltip: added ? 'Usuń z trasy' : 'Dodaj jako punkt trasy',
          icon: Icon(added ? Icons.remove_circle : Icons.add_circle,
            color: added ? Colors.green : Colors.orange),
          onPressed: () => added ? routeVM.removeWaypoint(poi.coordinate) : routeVM.addWaypoint(poi.coordinate),
        ),
      ),
    );
  }

  void _showHomeSheet() {
    final settings = context.read<SettingsProvider>();
    final routeVM = context.read<RouteProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _HomeSheet(
        settings: settings,
        onUseAsStart: (home) {
          Navigator.pop(ctx);
          routeVM.setStartLocation(LatLng(home.lat, home.lon));
          _startController.text = home.name;
        },
      ),
    );
  }

  void _onSearchChanged(TextEditingController controller, String query) {
    _debounce?.cancel();
    final seq = ++_searchSequence;
    if (query.length < 3) {
      setState(() {
        if (controller == _startController) _startResults = [];
        else _endResults = [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _searchLocation(query, (r) {
        if (seq != _searchSequence || !mounted) return;
        setState(() {
          if (controller == _startController) _startResults = r;
          else _endResults = r;
        });
      });
    });
  }

  void _searchLocation(String query, Function(List<GeocodingResult>) onResult) async {
    final results = await GeocodingService.shared.search(query);
    if (mounted) onResult(results);
  }

  IconData _poiIcon(POICategory category) {
    switch (category) {
      case POICategory.viewpoint: return Icons.visibility;
      case POICategory.mountainPass: return Icons.terrain;
      case POICategory.scenicRoad: return Icons.route;
      case POICategory.fuel: return Icons.local_gas_station;
      case POICategory.service: return Icons.build;
      case POICategory.accommodation: return Icons.hotel;
      case POICategory.restaurant: return Icons.restaurant;
    }
  }
}

class _HomeSheet extends StatefulWidget {
  final SettingsProvider settings;
  final void Function(HomeAddress) onUseAsStart;

  const _HomeSheet({required this.settings, required this.onUseAsStart});

  @override
  State<_HomeSheet> createState() => _HomeSheetState();
}

class _HomeSheetState extends State<_HomeSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<GeocodingResult> _results = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final home = widget.settings.home;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Adres domowy', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Użyj adresu domowego jako punktu startu.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
            if (home != null) ...[
              const SizedBox(height: 12),
              Card(
                color: Colors.orange.shade50,
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.home, color: Colors.deepOrange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(home.name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                      IconButton(
                        tooltip: 'Użyj jako start',
                        icon: const Icon(Icons.play_arrow, color: Colors.green),
                        onPressed: () => widget.onUseAsStart(home),
                      ),
                      IconButton(
                        tooltip: 'Usuń',
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => widget.settings.clearHome(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Wpisz adres domowy...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (q) => _onSearch(q),
            ),
            if (_results.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (_, i) => ListTile(
                    dense: true,
                    title: Text(_results[i].displayName, style: const TextStyle(fontSize: 13)),
                    onTap: () {
                      final r = _results[i];
                      widget.settings.setHome(HomeAddress(
                        name: r.displayName,
                        lat: r.lat,
                        lon: r.lon,
                      ));
                      setState(() => _results = []);
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _onSearch(String query) {
    _debounce?.cancel();
    if (query.length < 3) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      final results = await GeocodingService.shared.search(query);
      if (mounted) setState(() => _results = results);
    });
  }
}

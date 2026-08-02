import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/route.dart';
import '../providers/route_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/weather_provider.dart';
import '../services/geocoding_service.dart';
import '../widgets/home_sheet.dart';
import '../widgets/section_header.dart';
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
    return Consumer2<RouteProvider, WeatherProvider>(
      builder: (context, routeVM, weatherVM, _) {
        final route = routeVM.currentRoute;
        if (route != null && route.id != _loadedRouteId) {
          _loadedRouteId = route.id;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            weatherVM.loadWeather(route);
            if (_navigateOnReady) {
              _navigateOnReady = false;
              widget.onRoutePlanned?.call();
            }
          });
        }
        return Scaffold(
          body: Column(
            children: [
              SectionHeader(
                title: 'Planowanie trasy',
                icon: Icons.route,
                actions: [
                  IconButton(
                    tooltip: 'Adres domowy',
                    icon: const Icon(Icons.home_outlined),
                    color: Colors.white,
                    onPressed: _showHomeSheet,
                  ),
                  TextButton.icon(
                    onPressed: () => routeVM.useCurrentLocation(),
                    icon: const Icon(Icons.gps_fixed, size: 18),
                    label: const Text('GPS'),
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                  ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
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
                        onHomeTap: _useHomeAsStart,
                        onSelected: (loc) {
                          _startController.text = loc.displayName;
                          routeVM.setStartLocation(LatLng(loc.lat, loc.lon));
                          _startResults = [];
                        },
                        onChanged: (q) =>
                            _searchLocation(q, (r) => _startResults = r),
                      ),
                      const SizedBox(height: 12),
                      _buildLocationField(
                        controller: _endController,
                        icon: Icons.flag,
                        color: Colors.red,
                        hint: 'Wpisz miejsce docelowe...',
                        results: _endResults,
                        onHomeTap: _useHomeAsEnd,
                        onSelected: (loc) {
                          _endController.text = loc.displayName;
                          routeVM.setEndLocation(LatLng(loc.lat, loc.lon));
                          _endResults = [];
                        },
                        onChanged: (q) =>
                            _searchLocation(q, (r) => _endResults = r),
                      ),
                      const SizedBox(height: 24),
                      _buildOptions(routeVM),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: (routeVM.startLocation != null &&
                                routeVM.endLocation != null)
                            ? () {
                                setState(() => _navigateOnReady = true);
                                routeVM.planRoute(routeVM.startLocation!,
                                    routeVM.endLocation!);
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
                        Text(routeVM.errorMessage!,
                            style: const TextStyle(color: Colors.red)),
                      ],
                      if (routeVM.currentRoute != null) ...[
                        const SizedBox(height: 24),
                        _buildConfirmation(routeVM),
                        if (routeVM.intermediateWaypoints.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: routeVM.intermediateWaypoints
                                .map((w) => InputChip(
                                      label: const Text('Punkt pośredni',
                                          style: TextStyle(fontSize: 12)),
                                      onDeleted: () =>
                                          routeVM.removeWaypoint(w),
                                      deleteIconColor: Colors.red,
                                    ))
                                .toList(),
                          ),
                        ],
                      ],
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

  Widget _buildLocationField({
    required TextEditingController controller,
    required IconData icon,
    required Color color,
    required String hint,
    required List<GeocodingResult> results,
    required void Function(GeocodingResult) onSelected,
    required void Function(String) onChanged,
    VoidCallback? onHomeTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(hint,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const Spacer(),
            if (onHomeTap != null)
              TextButton.icon(
                onPressed: onHomeTap,
                icon: const Icon(Icons.home, size: 16),
                label: const Text('Dom',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.deepOrange,
                  visualDensity: VisualDensity.compact,
                ),
              ),
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
              onPressed: () {
                controller.clear();
                onChanged('');
              },
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
                title: Text(results[i].displayName,
                    style: const TextStyle(fontSize: 13)),
                subtitle: Text(
                    '${results[i].lat.toStringAsFixed(4)}, ${results[i].lon.toStringAsFixed(4)}',
                    style: const TextStyle(fontSize: 11)),
                onTap: () => onSelected(results[i]),
              ),
            ),
          ),
      ],
    );
  }

  void _useHomeAsStart() {
    final home = context.read<SettingsProvider>().home;
    if (home == null) {
      _showHomeSheet();
      return;
    }
    final routeVM = context.read<RouteProvider>();
    routeVM.setStartLocation(LatLng(home.lat, home.lon));
    _startController.text = home.name;
  }

  void _useHomeAsEnd() {
    final home = context.read<SettingsProvider>().home;
    if (home == null) {
      _showHomeSheet();
      return;
    }
    final routeVM = context.read<RouteProvider>();
    routeVM.setEndLocation(LatLng(home.lat, home.lon));
    _endController.text = home.name;
  }

  Widget _buildOptions(RouteProvider routeVM) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Preferencje trasy',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Unikaj autostrad'),
              subtitle: const Text('Bardziej malownicze drogi'),
              value: routeVM.routeOptions.avoidHighways,
              onChanged: (v) {
                routeVM.routeOptions.avoidHighways = v;
                routeVM.setRouteOptions(routeVM.routeOptions);
              },
            ),
            SwitchListTile(
              title: const Text('Preferuj kręte drogi'),
              subtitle: const Text('Więcej zakrętów = więcej frajdy'),
              value: routeVM.routeOptions.preferCurvyRoads,
              onChanged: (v) {
                routeVM.routeOptions.preferCurvyRoads = v;
                routeVM.setRouteOptions(routeVM.routeOptions);
              },
            ),
            SwitchListTile(
              title: const Text('Dodaj malownicze objazdy'),
              subtitle: const Text('Odwiedź ciekawe miejsca po drodze'),
              value: routeVM.routeOptions.includeScenicDetours,
              onChanged: (v) {
                routeVM.routeOptions.includeScenicDetours = v;
                routeVM.setRouteOptions(routeVM.routeOptions);
              },
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
                const Text('Trasa wyznaczona!',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text(route.name,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute(
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
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ],
        ),
      ),
    );
  }

  void _saveRoute(
      BuildContext context, RouteProvider routeVM, MotorcycleRoute route) {
    final already = routeVM.savedRoutes.any((r) => r.id == route.id);
    if (!already) routeVM.saveRoute(route);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(already
            ? 'Trasa jest już w Zapisane'
            : 'Trasa zapisana w Zapisane'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showHomeSheet() {
    showHomeSheet(context);
  }

  void _onSearchChanged(TextEditingController controller, String query) {
    _debounce?.cancel();
    final seq = ++_searchSequence;
    if (query.trim().toLowerCase() == 'dom') {
      final home = context.read<SettingsProvider>().home;
      if (home != null) {
        setState(() {
          final result = GeocodingResult(
            displayName: home.name,
            shortName: 'Dom',
            lat: home.lat,
            lon: home.lon,
          );
          if (controller == _startController)
            _startResults = [result];
          else
            _endResults = [result];
        });
        return;
      }
    }
    if (query.length < 3) {
      setState(() {
        if (controller == _startController)
          _startResults = [];
        else
          _endResults = [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _searchLocation(query, (r) {
        if (seq != _searchSequence || !mounted) return;
        setState(() {
          if (controller == _startController)
            _startResults = r;
          else
            _endResults = r;
        });
      });
    });
  }

  void _searchLocation(
      String query, Function(List<GeocodingResult>) onResult) async {
    final results = await GeocodingService.shared.search(query);
    if (mounted) onResult(results);
  }
}

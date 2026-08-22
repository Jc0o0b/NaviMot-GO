import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/country.dart';
import '../models/route.dart';
import '../models/traffic_regulations.dart';
import '../providers/events_provider.dart';
import '../providers/route_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/weather_provider.dart';
import '../services/geocoding_service.dart';
import '../services/location_service.dart';
import '../services/traffic_service.dart';
import '../utils/route_proximity.dart';
import '../widgets/event_widgets.dart';

import '../widgets/home_sheet.dart';
import '../widgets/offline_route_preview.dart';
import '../widgets/section_header.dart';
import '../widgets/traffic_overlay.dart';
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
  final _waypointController = TextEditingController();
  List<GeocodingResult> _startResults = [];
  List<GeocodingResult> _endResults = [];
  List<GeocodingResult> _waypointResults = [];
  Timer? _debounce;
  int _searchSequence = 0;
  bool _startLoading = false;
  bool _endLoading = false;
  bool _waypointLoading = false;
  String? _loadedRouteId;
  bool _navigateOnReady = false;
  bool _addingWaypoint = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _startController.dispose();
    _endController.dispose();
    _waypointController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<RouteProvider, WeatherProvider, EventsProvider>(
      builder: (context, routeVM, weatherVM, eventsVM, _) {
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
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 360 ? 10 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _useCurrentLocation,
                        icon: const Icon(Icons.gps_fixed, size: 18),
                        label: const Text('Aktualna lokalizacja'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.deepOrange,
                          side: const BorderSide(
                              color: Colors.deepOrange, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildLocationField(
                        controller: _startController,
                        icon: Icons.motorcycle,
                        color: Colors.green,
                        hint: 'Wpisz miejsce startu...',
                        results: _startResults,
                        loading: _startLoading,
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
                        loading: _endLoading,
                        onHomeTap: _useHomeAsEnd,
                        onSelected: (loc) {
                          _endController.text = loc.displayName;
                          routeVM.setEndLocation(LatLng(loc.lat, loc.lon));
                          _endResults = [];
                        },
                        onChanged: (q) =>
                            _searchLocation(q, (r) => _endResults = r),
                      ),
                      const SizedBox(height: 12),
                      if (_addingWaypoint)
                        _buildLocationField(
                          controller: _waypointController,
                          icon: Icons.add_location_alt_outlined,
                          color: Colors.blue,
                          hint: 'Wpisz przystanek po drodze...',
                          results: _waypointResults,
                          loading: _waypointLoading,
                          onSelected: (loc) {
                            _waypointController.text = loc.displayName;
                            routeVM.addWaypoint(LatLng(loc.lat, loc.lon));
                            _waypointResults = [];
                          },
                          onChanged: (q) =>
                              _searchLocation(q, (r) => _waypointResults = r),
                        )
                      else
                        FilledButton.icon(
                          onPressed: () =>
                              setState(() => _addingWaypoint = true),
                          icon: const Icon(Icons.add),
                          label: const Text('Dodaj przystanek na trasie'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      if (routeVM.intermediateWaypoints.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildStopList(routeVM),
                      ],
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
                        _buildConfirmation(routeVM, eventsVM),
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
    bool loading = false,
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
            suffixIcon: loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
          ),
          onChanged: (q) => _onSearchChanged(controller, q),
        ),
        if (results.isEmpty && loading && controller.text.length >= 3)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Szukam...',
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ),
        if (results.isEmpty && !loading && GeocodingService.shared.lastError != null && controller.text.length >= 3)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Błąd: ${GeocodingService.shared.lastError}',
                style: TextStyle(fontSize: 11, color: Colors.red[400])),
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
            const Divider(height: 16),
            Row(
              children: [
                const Icon(Icons.public, color: Colors.deepOrange, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pomiń kraj na trasie',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('Omijaj wybrany kraj, przez który przebiega trasa',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String?>(
                  value: routeVM.routeOptions.skipCountryCode,
                  underline: const SizedBox.shrink(),
                  icon: const Icon(Icons.arrow_drop_down),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Brak'),
                    ),
                    for (final c in Country.all)
                      DropdownMenuItem<String?>(
                        value: c.code,
                        child: Text(c.name),
                      ),
                  ],
                  onChanged: (code) {
                    routeVM.routeOptions.skipCountryCode = code;
                    routeVM.setRouteOptions(routeVM.routeOptions);
                    final start = routeVM.startLocation;
                    final end = routeVM.endLocation;
                    if (code != null && start != null && end != null) {
                      setState(() => _navigateOnReady = false);
                      routeVM.planRoute(start, end);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmation(RouteProvider routeVM, EventsProvider eventsVM) {
    final route = routeVM.currentRoute!;
    final nearPlaces = itemsWithinRoute(
      eventsVM.importantPlaces,
      route.waypoints,
      5000,
      (p) => LatLng(p.lat, p.lon),
    );
    final nearEvents = itemsWithinRoute(
      [...eventsVM.events, ...routeVM.routeCameras],
      route.waypoints,
      5000,
      (e) => LatLng(e.lat, e.lon),
    );
    final traffic =
        TrafficService.shared.trafficAlongRoute(route.waypoints, nearEvents);
    final hasBlock = TrafficService.shared.hasBlock(traffic);
    final hasSlow = TrafficService.shared.hasSlow(traffic);
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
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.alarm, size: 15, color: Colors.deepOrange),
                const SizedBox(width: 6),
                Text(
                  'Przyjazd ok. ${PolishTrafficRegulations.shared
                      .calculateTravelTime(route.totalDistance, route.roadTypes)
                      .formattedArrival()}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.deepOrange),
                ),
              ],
            ),
            if (hasBlock || hasSlow) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: (hasBlock ? Colors.red : Colors.orange).withValues(
                      alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: hasBlock ? Colors.red : Colors.orange,
                      width: 1),
                ),
                child: Row(
                  children: [
                    Icon(
                      hasBlock
                          ? Icons.block
                          : Icons.traffic,
                      size: 18,
                      color: hasBlock ? Colors.red : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hasBlock
                            ? 'Uwaga: blokada drogi na trasie (czerwone odcinki na linii trasy)'
                            : 'Uwaga: spowolnienia ruchu na trasie (pomarańczowe odcinki na linii trasy)',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              height: 170,
              child: OfflineRoutePreview(
                route: route,
                events: nearEvents,
                places: nearPlaces,
                label: null,
              ),
            ),
            if (hasBlock || hasSlow) ...[
              const SizedBox(height: 8),
              TrafficLegend(hasSlow: hasSlow, hasBlock: hasBlock),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => NavigationScreen(
                        route: route,
                        intermediateWaypoints:
                            routeVM.intermediateWaypoints,
                      ),
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
            const SizedBox(height: 8),
            if (nearEvents.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.red, size: 20),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text('Wydarzenia na trasie',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Zgłoszone przez użytkowników oraz dane live traffic',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              for (final e in nearEvents.take(6))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(eventIcon(e.type),
                          size: 16, color: roadEventColor(e.type)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.type.label,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            if (e.description != null &&
                                e.description!.isNotEmpty)
                              Text(e.description!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (nearPlaces.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(Icons.star, color: Colors.amber, size: 20),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text('Ważne miejsca w pobliżu trasy',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Miejsca zgłoszone przez innych użytkowników',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              for (final p in nearPlaces.take(5))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.star_border,
                          size: 16, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            if (p.note.isNotEmpty)
                              Text(p.note,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
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

  Future<void> _useCurrentLocation() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pobieranie lokalizacji...'),
        duration: Duration(seconds: 2),
      ),
    );
    final location = await LocationService.getCurrentLocation();
    if (!mounted) return;
    if (location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nie udało się pobrać lokalizacji'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final routeVM = context.read<RouteProvider>();
    final choice = await showDialog<_LocTarget>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Dodaj aktualną lokalizację'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(_LocTarget.start),
            child: const Row(
              children: [
                Icon(Icons.motorcycle, color: Colors.green, size: 20),
                SizedBox(width: 12),
                Text('Miejsce startu'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(_LocTarget.end),
            child: const Row(
              children: [
                Icon(Icons.flag, color: Colors.red, size: 20),
                SizedBox(width: 12),
                Text('Miejsce docelowe'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(_LocTarget.waypoint),
            child: const Row(
              children: [
                Icon(Icons.add_location_alt_outlined,
                    color: Colors.blue, size: 20),
                SizedBox(width: 12),
                Text('Przystanek po drodze'),
              ],
            ),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    const label = 'Aktualna lokalizacja';
    switch (choice) {
      case _LocTarget.start:
        routeVM.setStartLocation(location);
        _startController.text = label;
        break;
      case _LocTarget.end:
        routeVM.setEndLocation(location);
        _endController.text = label;
        break;
      case _LocTarget.waypoint:
        routeVM.addWaypoint(location);
        break;
    }
    setState(() {
      _startResults = [];
      _endResults = [];
      _waypointResults = [];
    });
  }

  void _onSearchChanged(TextEditingController controller, String query) {
    _debounce?.cancel();
    final seq = ++_searchSequence;

    void updateResults(List<GeocodingResult> r) {
      if (seq != _searchSequence || !mounted) return;
      setState(() {
        if (controller == _startController) {
          _startResults = r;
          _startLoading = false;
        } else if (controller == _endController) {
          _endResults = r;
          _endLoading = false;
        } else {
          _waypointResults = r;
          _waypointLoading = false;
        }
      });
    }

    if (query.trim().toLowerCase() == 'dom') {
      final home = context.read<SettingsProvider>().home;
      if (home != null) {
        updateResults([
          GeocodingResult(
            displayName: home.name,
            shortName: 'Dom',
            lat: home.lat,
            lon: home.lon,
          ),
        ]);
        return;
      }
    }
    if (query.length < 3) {
      updateResults([]);
      return;
    }
    setState(() {
      if (controller == _startController) {
        _startLoading = true;
      } else if (controller == _endController) {
        _endLoading = true;
      } else {
        _waypointLoading = true;
      }
    });
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _searchLocation(query, updateResults);
    });
  }

  Widget _buildStopList(RouteProvider routeVM) {
    final waypoints = routeVM.intermediateWaypoints;
    final items = <Object>[...waypoints, const _DestinationStop()];
    final start = routeVM.startLocation;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            _StopTile(
              icon: Icons.motorcycle,
              color: Colors.green,
              title: 'Start',
              subtitle: start == null
                  ? null
                  : '${start.latitude.toStringAsFixed(4)}, '
                      '${start.longitude.toStringAsFixed(4)}',
            ),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: items.length,
              onReorderItem: (oldIndex, newIndex) {
                final updated = List<Object>.from(items);
                if (newIndex > oldIndex) newIndex--;
                final moved = updated.removeAt(oldIndex);
                updated.insert(newIndex, moved);
                routeVM.setWaypointOrder(
                    updated.whereType<LatLng>().toList());
              },
              itemBuilder: (context, index) {
                final item = items[index];
                if (item is _DestinationStop) {
                  return _StopTile(
                    key: const ValueKey('dest'),
                    index: index,
                    icon: Icons.flag,
                    color: Colors.red,
                    title: 'Miejsce docelowe',
                    draggable: true,
                  );
                }
                final wp = item as LatLng;
                return _StopTile(
                  key: ValueKey(
                      'wp-${wp.latitude},${wp.longitude}'),
                  index: index,
                  icon: Icons.place,
                  color: Colors.blue,
                  title: 'Przystanek ${waypoints.indexOf(wp) + 1}',
                  subtitle: '${wp.latitude.toStringAsFixed(4)}, '
                      '${wp.longitude.toStringAsFixed(4)}',
                  draggable: true,
                  onDelete: () => routeVM.removeWaypoint(wp),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _searchLocation(
      String query, Function(List<GeocodingResult>) onResult) async {
    final results = await GeocodingService.shared.search(query);
    if (mounted) onResult(results);
  }
}

class _DestinationStop {
  const _DestinationStop();
}

enum _LocTarget { start, end, waypoint }

class _StopTile extends StatelessWidget {
  final int? index;
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final bool draggable;
  final VoidCallback? onDelete;

  const _StopTile({
    super.key,
    this.index,
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.draggable = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: const TextStyle(fontSize: 11, color: Colors.grey))
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.red),
              visualDensity: VisualDensity.compact,
              tooltip: 'Usuń przystanek',
              onPressed: onDelete,
            ),
          if (draggable && index != null)
            ReorderableDragStartListener(
              index: index!,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.drag_handle, color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }
}

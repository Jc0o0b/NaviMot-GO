import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/point_of_interest.dart';
import '../models/route.dart';
import '../models/weather_point.dart';
import '../providers/events_provider.dart';
import '../providers/route_provider.dart';
import '../providers/weather_provider.dart';
import '../providers/poi_provider.dart';
import '../widgets/event_widgets.dart';
import '../widgets/weather_icon.dart';
import '../widgets/poi_marker.dart';
import 'navigation_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  String? _fittedRouteId;
  String? _poisLoadedRouteId;
  bool _poisShownOnMap = false;
  String? _focusedPoiId;
  LatLng _mapCenter = const LatLng(52.2297, 21.0122);

  late final AnimationController _drawCtrl;
  Animation<double>? _drawAnim;
  List<LatLng> _animPoints = [];
  int _animCount = 0;
  bool _animDone = false;

  @override
  void initState() {
    super.initState();
    _drawCtrl = AnimationController(vsync: this)..addListener(_onDrawTick);
  }

  @override
  void dispose() {
    _drawCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final route =
        context.select<RouteProvider, MotorcycleRoute?>((p) => p.currentRoute);
    if (route != null && route.id != _fittedRouteId) {
      _fittedRouteId = route.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || context.read<RouteProvider>().currentRoute == null)
          return;
        final r = context.read<RouteProvider>().currentRoute!;
        _fitRoute(r);
        _startRouteAnimation(r);
        _ensurePoisLoaded(r);
      });
    }

    final selectedPoi = context.watch<POIProvider>().selectedPOI;
    if (selectedPoi != null && selectedPoi.id != _focusedPoiId) {
      _focusedPoiId = selectedPoi.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final s = context.read<POIProvider>().selectedPOI;
        if (s == null) return;
        setState(() => _poisShownOnMap = true);
        try {
          _mapController.move(s.coordinate, 13);
        } catch (_) {}
      });
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: route?.waypoints.isNotEmpty == true
                ? _centerOf(route!.waypoints)
                : const LatLng(52.2297, 21.0122),
            initialZoom: route?.waypoints.isNotEmpty == true ? 9.0 : 6.0,
            onTap: _handleMapTap,
            onPositionChanged: (camera, hasGesture) {
              final center = camera.center;
              if (center != null) _mapCenter = center;
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.motorcycle.routes',
              maxNativeZoom: 19,
            ),
            if (route != null) ...[
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: route.waypoints,
                    color: Colors.white,
                    strokeWidth: 8,
                  ),
                  if (_animDone)
                    Polyline(
                      points: route.waypoints,
                      color: Colors.deepOrange,
                      strokeWidth: 5,
                    )
                  else
                    Polyline(
                      points: _animPoints.take(max(1, _animCount)).toList(),
                      color: Colors.deepOrange,
                      strokeWidth: 5,
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  _buildMarker(
                      route.waypoints.first, Icons.motorcycle, Colors.green),
                  if (route.waypoints.length > 1)
                    _buildMarker(route.waypoints.last, Icons.flag, Colors.red),
                ],
              ),
            ],
            const RepaintBoundary(child: _WeatherMarkersLayer()),
            RepaintBoundary(child: _POIMarkersLayer(visible: _poisShownOnMap)),
            const RepaintBoundary(child: _EventMarkersLayer()),
          ],
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 12,
          child: FloatingActionButton.small(
            heroTag: 'report-event',
            tooltip: 'Zgłoś wydarzenie na drodze',
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            onPressed: () => showEventReportSheet(
              context,
              fallbackLocation: _mapCenter,
            ),
            child: const Icon(Icons.warning_amber_rounded),
          ),
        ),
        if (route != null)
          _SummaryOverlay(
            route: route,
            poiVM: context.watch<POIProvider>(),
            onShowPois: () => _ensurePoisLoaded(route),
            onPoiSelected: (poi) {
              setState(() => _poisShownOnMap = true);
              context.read<POIProvider>().selectPOI(poi);
              try {
                _mapController.move(poi.coordinate, 13);
              } catch (_) {}
            },
            onSave: _saveRoute,
          ),
      ],
    );
  }

  void _ensurePoisLoaded(MotorcycleRoute route) {
    if (mounted && _poisShownOnMap && _poisLoadedRouteId == route.id) return;
    _poisLoadedRouteId = route.id;
    setState(() => _poisShownOnMap = true);
    context.read<POIProvider>().loadPOIs(route, radius: 10000);
  }

  void _handleMapTap(TapPosition tapPosition, LatLng point) {
    context.read<POIProvider>().selectPOI(null);
    final route = context.read<RouteProvider>().currentRoute;
    if (route == null || route.waypoints.length < 2) return;
    final zoom = _mapController.camera.zoom;
    final metersPerPixel =
        156543.03392 * cos(point.latitude * pi / 180) / pow(2, zoom);
    final threshold = 50 * metersPerPixel;
    if (_minDistanceToRoute(point, route.waypoints) <= threshold) {
      _ensurePoisLoaded(route);
    }
  }

  double _minDistanceToRoute(LatLng point, List<LatLng> waypoints) {
    const r = 6371000.0;
    final cosLat = cos(point.latitude * pi / 180);
    var minDist = double.infinity;
    for (final w in waypoints) {
      final dLat = (w.latitude - point.latitude) * pi / 180;
      final dLon = (w.longitude - point.longitude) * pi / 180;
      final d = sqrt(dLat * dLat + dLon * dLon * cosLat * cosLat) * r;
      if (d < minDist) minDist = d;
    }
    return minDist;
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

  void _fitRoute(MotorcycleRoute route) {
    try {
      _mapController.fitCamera(CameraFit.coordinates(
        coordinates: route.waypoints,
        padding: const EdgeInsets.fromLTRB(48, 80, 48, 300),
      ));
    } catch (_) {}
  }

  void _startRouteAnimation(MotorcycleRoute route) {
    _animPoints = _decimatePoints(route.waypoints, 400);
    _animCount = 1;
    _animDone = false;
    final km = route.totalDistance / 1000.0;
    final millis = (2200 + km * 20).round().clamp(2200, 5500);
    _drawCtrl.duration = Duration(milliseconds: millis);
    _drawAnim = CurvedAnimation(parent: _drawCtrl, curve: Curves.easeInOut);
    _drawCtrl.forward(from: 0);
  }

  void _onDrawTick() {
    if (_animPoints.isEmpty) return;
    final anim = _drawAnim;
    final total = _animPoints.length;
    if (_drawCtrl.isCompleted) {
      if (!_animDone) {
        _animDone = true;
        setState(() => _animCount = total);
      }
      return;
    }
    final target = anim == null ? total : max(1, (anim.value * total).round());
    if (target != _animCount && (target - _animCount).abs() >= 6) {
      setState(() => _animCount = target);
    }
  }

  List<LatLng> _decimatePoints(List<LatLng> points, int target) {
    if (points.length <= target) return points;
    final out = <LatLng>[];
    for (var i = 0; i < target; i++) {
      out.add(points[(i * (points.length - 1) / (target - 1)).round()]);
    }
    return out;
  }

  Marker _buildMarker(LatLng point, IconData icon, Color color) {
    return Marker(
      point: point,
      width: 42,
      height: 42,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: 2),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }

  LatLng _centerOf(List<LatLng> points) {
    double lat = 0, lon = 0;
    for (final p in points) {
      lat += p.latitude;
      lon += p.longitude;
    }
    return LatLng(lat / points.length, lon / points.length);
  }
}

class _WeatherMarkersLayer extends StatelessWidget {
  const _WeatherMarkersLayer();

  static final Distance _dist = Distance();

  @override
  Widget build(BuildContext context) {
    final weatherVM = context.watch<WeatherProvider>();
    if (weatherVM.weatherPoints.isEmpty) return const SizedBox.shrink();
    final poiVM = context.watch<POIProvider>();
    final poiCoords = <LatLng>[
      for (final p in poiVM.pointsOfInterest) p.coordinate,
      if (poiVM.selectedPOI != null) poiVM.selectedPOI!.coordinate,
    ];
    final shown = <WeatherPoint>[];
    for (final wp in weatherVM.weatherPoints) {
      if (poiCoords.any((c) => _dist.distance(wp.coordinate, c) < 1200)) {
        continue;
      }
      if (shown.any((s) => _dist.distance(s.coordinate, wp.coordinate) < 500)) {
        continue;
      }
      shown.add(wp);
    }
    if (shown.isEmpty) return const SizedBox.shrink();
    return MarkerLayer(
      markers: shown
          .map((wp) => Marker(
                point: wp.coordinate,
                width: 44,
                height: 44,
                child: WeatherIconWidget(point: wp),
              ))
          .toList(),
    );
  }
}

class _POIMarkersLayer extends StatelessWidget {
  final bool visible;
  const _POIMarkersLayer({required this.visible});

  @override
  Widget build(BuildContext context) {
    final poiVM = context.watch<POIProvider>();
    final selected = poiVM.selectedPOI;
    if (!visible || poiVM.pointsOfInterest.isEmpty)
      return const SizedBox.shrink();
    final markers = poiVM.pointsOfInterest
        .take(30)
        .map((poi) => Marker(
              point: poi.coordinate,
              width: 40,
              height: 40,
              child: POIMarkerWidget(poi: poi),
            ))
        .toList();
    if (selected != null) {
      markers.add(Marker(
        point: selected.coordinate,
        width: 48,
        height: 48,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.deepOrange, width: 3),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6)],
          ),
          child: const Icon(Icons.place, color: Colors.deepOrange, size: 30),
        ),
      ));
    }
    return MarkerLayer(markers: markers);
  }
}

class _EventMarkersLayer extends StatelessWidget {
  const _EventMarkersLayer();

  @override
  Widget build(BuildContext context) {
    final eventsVM = context.watch<EventsProvider>();
    final markers = <Marker>[
      for (final e in eventsVM.events.take(60))
        Marker(
          point: LatLng(e.lat, e.lon),
          width: 36,
          height: 36,
          child: GestureDetector(
            onTap: () => showEventDetail(context, e),
            child: RoadEventMarker(type: e.type),
          ),
        ),
      for (final p in eventsVM.importantPlaces.take(40))
        Marker(
          point: LatLng(p.lat, p.lon),
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () => showImportantPlaceDetail(context, p),
            child: const ImportantPlaceMarker(),
          ),
        ),
    ];
    if (markers.isEmpty) return const SizedBox.shrink();
    return MarkerLayer(markers: markers);
  }
}

class _SummaryOverlay extends StatelessWidget {
  final MotorcycleRoute route;
  final POIProvider poiVM;
  final VoidCallback onShowPois;
  final void Function(PointOfInterest) onPoiSelected;
  final void Function(BuildContext, RouteProvider, MotorcycleRoute) onSave;

  const _SummaryOverlay({
    required this.route,
    required this.poiVM,
    required this.onShowPois,
    required this.onPoiSelected,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final routeVM = context.watch<RouteProvider>();
    final weatherVM = context.watch<WeatherProvider>();
    final travel = routeVM.travelTimeInfo;
    final surface = Theme.of(context).colorScheme.surface;

    return Positioned(
      left: 8,
      right: 8,
      bottom: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Card(
            margin: EdgeInsets.zero,
            elevation: 4,
            color: surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.icon(
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => NavigationScreen(route: route),
                    )),
                    icon: const Icon(Icons.navigation, size: 20),
                    label: const Text('Start nawigacji'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.route,
                          size: 18, color: Colors.deepOrange),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          route.name,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text('${route.scenicScore}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  if (travel != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _summaryItem(Icons.schedule,
                            travel.formattedDrivingTime, 'Czas jazdy'),
                        _summaryItem(Icons.timer_outlined,
                            travel.formattedTotalTime, 'Z przerwami'),
                        _summaryItem(Icons.straighten, travel.formattedDistance,
                            'Dystans'),
                        _summaryItem(
                            Icons.speed, travel.formattedSpeed, 'Średnia'),
                      ],
                    ),
                  ],
                  if (route.roadTypes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final t in route.roadTypes)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.deepOrange, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_roadIcon(t),
                                    size: 13, color: Colors.deepOrange),
                                const SizedBox(width: 4),
                                Text(t.label,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (weatherVM.weatherPoints.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _weatherItem(weatherVM.predominantCondition),
                        _summaryItem(
                            Icons.thermostat,
                            '${weatherVM.averageTemperature.round()}°',
                            'Temperatura'),
                        _summaryItem(Icons.air,
                            '${weatherVM.maxWindSpeed.round()} km/h', 'Wiatr'),
                        _summaryItem(
                            Icons.water_drop,
                            '${weatherVM.maxPrecipitationProbability.round()}%',
                            'Opady'),
                      ],
                    ),
                  ],
                  if (routeVM.routeAlternatives.length > 1) ...[
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    _buildAlternatives(routeVM),
                  ],
                  const SizedBox(height: 4),
                  _buildMotorcyclistSection(context),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => onSave(context, routeVM, route),
                    icon: const Icon(Icons.bookmark, size: 18),
                    label: const Text('Zapisz trasę'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepOrange,
                      side: const BorderSide(color: Colors.deepOrange, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (weatherVM.weatherAlert != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(weatherVM.weatherAlert!,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAlternatives(RouteProvider routeVM) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Warianty trasy',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        for (final alt in routeVM.routeAlternatives)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _AlternativeTile(
              route: alt,
              selected: routeVM.currentRoute?.id == alt.id,
              onTap: () => routeVM.selectRoute(alt),
            ),
          ),
      ],
    );
  }

  Widget _buildMotorcyclistSection(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      shape: const Border(),
      collapsedShape: const Border(),
      leading: const Icon(Icons.attractions, color: Colors.deepOrange),
      title: const Text('Dla motocyklisty',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      subtitle: Text(
        poiVM.pointsOfInterest.isEmpty
            ? 'Miejsca wzdłuż trasy'
            : '${poiVM.pointsOfInterest.length} miejsc wzdłuż trasy',
        style: const TextStyle(fontSize: 11),
      ),
      children: [
        if (poiVM.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (poiVM.pointsOfInterest.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: TextButton.icon(
              onPressed: onShowPois,
              icon: const Icon(Icons.search, size: 18),
              label: const Text('Wyszukaj miejsca wzdłuż trasy'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.deepOrange,
                textStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: min(poiVM.pointsOfInterest.length, 20),
              itemBuilder: (_, i) {
                final poi = poiVM.pointsOfInterest[i];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor:
                        Colors.orange.withValues(alpha: 0.2),
                    child: Icon(_poiIcon(poi.category),
                        color: Colors.orange, size: 16),
                  ),
                  title: Text(poi.name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  subtitle: Text(poi.category.label,
                      style: const TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => onPoiSelected(poi),
                );
              },
            ),
          ),
      ],
    );
  }

  IconData _poiIcon(POICategory category) {
    switch (category) {
      case POICategory.viewpoint:
        return Icons.visibility;
      case POICategory.mountainPass:
        return Icons.terrain;
      case POICategory.scenicRoad:
        return Icons.route;
      case POICategory.fuel:
        return Icons.local_gas_station;
      case POICategory.service:
        return Icons.build;
      case POICategory.accommodation:
        return Icons.hotel;
      case POICategory.restaurant:
        return Icons.restaurant;
    }
  }

  Widget _summaryItem(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.deepOrange),
            const SizedBox(width: 3),
            Text(value,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
      ],
    );
  }

  Widget _weatherItem(WeatherCondition condition) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_conditionIcon(condition), size: 14, color: Colors.deepOrange),
        const SizedBox(height: 2),
        Text(_conditionLabel(condition),
            style: const TextStyle(fontSize: 9, color: Colors.grey)),
      ],
    );
  }

  IconData _conditionIcon(WeatherCondition c) {
    switch (c) {
      case WeatherCondition.sunny:
        return Icons.wb_sunny;
      case WeatherCondition.partlyCloudy:
        return Icons.cloud;
      case WeatherCondition.cloudy:
        return Icons.cloud_queue;
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

  String _conditionLabel(WeatherCondition c) {
    switch (c) {
      case WeatherCondition.sunny:
        return 'Słonecznie';
      case WeatherCondition.partlyCloudy:
        return 'Częściowo';
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

  IconData _roadIcon(RoadType type) {
    switch (type) {
      case RoadType.highway:
        return Icons.local_shipping;
      case RoadType.expressway:
        return Icons.directions_car;
      case RoadType.national:
        return Icons.route;
      case RoadType.regional:
        return Icons.swap_horiz;
      case RoadType.local:
        return Icons.home;
      case RoadType.scenic:
        return Icons.forest;
      case RoadType.unpaved:
        return Icons.terrain;
    }
  }
}

class _AlternativeTile extends StatelessWidget {
  final MotorcycleRoute route;
  final bool selected;
  final VoidCallback onTap;

  const _AlternativeTile({
    required this.route,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fastest = route.label == 'Najszybsza';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Colors.deepOrange.withValues(alpha: 0.12)
              : Colors.grey.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? Colors.deepOrange
                : Colors.grey.withValues(alpha: 0.4),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              fastest ? Icons.bolt : Icons.forest,
              size: 20,
              color: fastest ? Colors.orange : Colors.green,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    route.label ?? 'Trasa',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.deepOrange : null,
                    ),
                  ),
                  Text(
                    '${_formatDuration(route.estimatedDuration)} · ${_formatDistance(route.totalDistance)}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: Colors.deepOrange, size: 18)
            else
              Text('${route.scenicScore} pkt',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  String _formatDuration(double seconds) {
    final h = (seconds / 3600).floor();
    final m = ((seconds % 3600) / 60).round();
    if (h > 0) return '$h h $m min';
    return '$m min';
  }

  String _formatDistance(double meters) {
    final km = meters / 1000.0;
    return km >= 100 ? '${km.toInt()} km' : '${km.toStringAsFixed(1)} km';
  }
}

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/road_event.dart';
import '../models/route.dart';
import '../models/route_step.dart';
import '../models/traffic_regulations.dart';
import '../providers/events_provider.dart';
import '../providers/route_provider.dart';
import '../providers/settings_provider.dart';
import '../services/location_service.dart';
import '../services/navigation_service.dart';
import '../services/routing_service.dart';
import '../services/traffic_service.dart';
import '../services/web_tts_service.dart';
import '../utils/route_geometry.dart';
import '../widgets/event_widgets.dart';
import '../widgets/traffic_overlay.dart';

class NavigationScreen extends StatefulWidget {
  final MotorcycleRoute route;
  final List<LatLng> intermediateWaypoints;
  final TileProvider? tileProvider;
  const NavigationScreen({
    super.key,
    required this.route,
    this.intermediateWaypoints = const [],
    this.tileProvider,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionSub;
  FlutterTts? _tts;
  Timer? _simTimer;
  Timer? _simFallbackTimer;
  bool _demoMode = false;
  double _simAlong = 0;
  double _simSpeedMs = 0;

  static const double _rerouteThresholdMeters = 200;
  static const Duration _rerouteCooldown = Duration(seconds: 10);

  /// Aktualna trasa (może być podmieniona po automatycznym objazdzie).
  late MotorcycleRoute _route;

  late List<double> _waypointCumulative;
  late List<double> _stepCumulative;
  late double _totalDistance;

  LatLng? _currentLocation;
  double _currentSpeed = 0;
  int _currentStepIndex = 0;
  int _nextStepIndex = 1;
  double _distanceToNext = 0;
  double _remainingDistance = 0;
  double _remainingDuration = 0;
  int _spokenStepIndex = -1;
  bool _arrived = false;
  bool _mapReady = false;
  DateTime _lastCameraMove = DateTime.fromMillisecondsSinceEpoch(0);

  bool _rerouting = false;
  DateTime _lastReroute = DateTime.fromMillisecondsSinceEpoch(0);

  RoadEvent? _upcomingAlert;
  double _upcomingAlertDistance = double.infinity;
  final Set<String> _spokenAlerts = {};
  DateTime _lastAlertCheck = DateTime.fromMillisecondsSinceEpoch(0);
  bool _ttsFailed = false;

  @override
  void initState() {
    super.initState();
    _route = widget.route;
    _recomputeRouteCache();
    _nextStepIndex = _nextMeaningfulStepIndex();
    _remainingDistance = _totalDistance;
    _remainingDuration = PolishTrafficRegulations.shared
        .calculateTravelTime(
            _route.totalDistance, _route.roadTypes)
        .drivingTime;
    _initTts();
    _startTracking();
  }

  void _recomputeRouteCache() {
    _waypointCumulative = _cumulativeDistances(_route.waypoints);
    _totalDistance = _waypointCumulative.isNotEmpty
        ? _waypointCumulative.last
        : _route.totalDistance;
    _stepCumulative = _computeStepCumulative(_route.steps);
  }

  Future<void> _initTts() async {
    if (kIsWeb) {
      await WebTtsService.shared.init();
      if (!WebTtsService.shared.isSupported) {
        _ttsFailed = true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Brak obsługi TTS — nawigacja głosowa niedostępna'),
            duration: Duration(seconds: 5),
          ));
        }
        return;
      }
    } else {
      try {
        final tts = FlutterTts();
        await tts.setLanguage('pl-PL');
        await tts.setSpeechRate(0.48);
        await tts.setVolume(1.0);
        _tts = tts;
      } catch (e) {
        _ttsFailed = true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Brak obsługi TTS — nawigacja głosowa niedostępna'),
            duration: const Duration(seconds: 5),
          ));
        }
        return;
      }
    }
    if (mounted && _route.steps.isNotEmpty) {
      final first = _route.steps.first;
      if (NavigationService.shared.shouldSpeak(first)) {
        _speak(NavigationService.shared.instructionFor(first));
      }
      _spokenStepIndex = 0;
    }
  }

  Future<void> _startTracking() async {
    _simFallbackTimer = Timer(const Duration(seconds: 10), _maybeEnterDemo);
    LatLng? location;
    try {
      location = await LocationService.getCurrentLocation();
    } catch (_) {}
    if (location != null && mounted) {
      _handleInitialPosition(location);
    }
    bool streamOk = false;
    try {
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen(_onPosition, onError: (_) {});
      streamOk = true;
    } catch (_) {}
    if (!streamOk && _currentLocation == null) {
      _simFallbackTimer?.cancel();
      _startSimulation();
    }
  }

  void _handleInitialPosition(LatLng location) {
    final snapped = _snapToRoute(location);
    final realToRoute = _distanceBetween(location, snapped);
    setState(() {
      _currentLocation = location;
      _simAlong = _distanceAlong(snapped);
    });
    _moveCameraTo(location);
    if (realToRoute > _rerouteThresholdMeters) {
      _maybeReroute(location, realToRoute);
    }
  }

  void _maybeEnterDemo() {
    if (mounted && _currentLocation == null && !_demoMode) {
      _startSimulation();
    }
  }

  void _startSimulation({String? notice}) {
    final pts = _route.waypoints;
    if (pts.isEmpty) return;
    _simTimer?.cancel();
    _demoMode = true;
    _simSpeedMs = 80 / 3.6;
    final loc = _snapToRoute(_currentLocation ?? pts.first);
    setState(() {
      _currentLocation = loc;
      _simAlong = _waypointCumulative.length > 1 ? _distanceAlong(loc) : 0;
    });
    _moveCameraTo(loc);
    _simTimer = Timer.periodic(
      const Duration(milliseconds: 120),
      (_) => _advanceSimulation(),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(notice ?? 'Brak sygnału GPS — uruchomiono tryb demo'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _advanceSimulation() {
    final pts = _route.waypoints;
    if (pts.length < 2) return;
    final total = _waypointCumulative.last;
    _simAlong += _simSpeedMs * 0.12;
    if (_simAlong >= total) {
      _simAlong = total;
      _simTimer?.cancel();
    }
    final loc = _pointAtAlong(_simAlong);
    setState(() {
      _currentLocation = loc;
      _currentSpeed = 80 + 6 * sin(_simAlong / 300);
      _updateProgress(loc);
    });
    _moveCameraTo(loc);
    if (_simAlong >= total) {
      setState(() => _arrived = true);
    }
  }

  LatLng _pointAtAlong(double along) {
    final pts = _route.waypoints;
    var i = 0;
    while (i < pts.length - 2 && _waypointCumulative[i + 1] < along) {
      i++;
    }
    final segStart = _waypointCumulative[i];
    final segLen = _waypointCumulative[i + 1] - segStart;
    final t = segLen <= 0 ? 0.0 : ((along - segStart) / segLen).clamp(0.0, 1.0);
    final a = pts[i];
    final b = pts[i + 1];
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }

  void _onPosition(Position pos) {
    if (!mounted) return;
    final real = LatLng(pos.latitude, pos.longitude);
    final snapped = _snapToRoute(real);
    final realToRoute = _distanceBetween(real, snapped);
    final speedMs = pos.speed.isFinite ? pos.speed : 0.0;
    if (_demoMode) {
      _simTimer?.cancel();
      _demoMode = false;
    }
    setState(() {
      _currentLocation = real;
      _currentSpeed = speedMs > 0.4 ? speedMs * 3.6 : 0;
      _updateProgress(snapped);
    });
    _moveCameraTo(real);
    if (realToRoute > _rerouteThresholdMeters) {
      _maybeReroute(real, realToRoute);
    }
  }

  LatLng _snapToRoute(LatLng p) {
    if (_route.waypoints.length < 2) return p;
    return _pointAtAlong(_distanceAlong(p));
  }

  double _distanceBetween(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLon = (b.longitude - a.longitude) * pi / 180;
    final la1 = a.latitude * pi / 180;
    final la2 = b.latitude * pi / 180;
    final h =
        pow(sin(dLat / 2), 2) + cos(la1) * cos(la2) * pow(sin(dLon / 2), 2);
    return 2 * r * asin(sqrt(h));
  }

  void _updateProgress(LatLng loc) {
    final steps = _route.steps;
    final along = _distanceAlong(loc);
    _remainingDistance = max(0, _totalDistance - along);
    final totalTravel = PolishTrafficRegulations.shared
        .calculateTravelTime(_route.totalDistance,
            _route.roadTypes)
        .drivingTime;
    _remainingDuration = _totalDistance > 0
        ? totalTravel * (_remainingDistance / _totalDistance)
        : 0;
    _updateAlert(along);
    if (steps.isEmpty) return;

    var cs = 0;
    for (var i = 0; i < _stepCumulative.length; i++) {
      if (_stepCumulative[i] <= along + 30) cs = i;
    }
    _currentStepIndex = cs;
    _nextStepIndex = _nextMeaningfulStepIndex();
    _distanceToNext = max(0, _stepCumulative[_nextStepIndex] - along);

    final lastIsArrive = steps.last.type == 'arrive';
    if (lastIsArrive &&
        _nextStepIndex == steps.length - 1 &&
        _distanceToNext <= 40) {
      if (!_arrived) {
        _arrived = true;
        _speak(NavigationService.shared.instructionFor(steps.last));
      }
      return;
    }

    if (!_arrived &&
        _nextStepIndex > _spokenStepIndex &&
        _distanceToNext <= 250) {
      _spokenStepIndex = _nextStepIndex;
      _speak(NavigationService.shared.instructionFor(steps[_nextStepIndex]));
    }
  }

  int _nextMeaningfulStepIndex() {
    final steps = _route.steps;
    if (steps.isEmpty) return -1;
    for (var i = _currentStepIndex + 1; i < steps.length; i++) {
      if (NavigationService.shared.shouldSpeak(steps[i])) return i;
    }
    return steps.length - 1;
  }

  void _updateAlert(double along) {
    final now = DateTime.now();
    if (now.difference(_lastAlertCheck).inMilliseconds < 400) return;
    _lastAlertCheck = now;
    final events = [
      ...context.read<RouteProvider>().routeCameras,
      ...context.read<EventsProvider>().events,
    ];
    RoadEvent? nearest;
    var nearestDist = double.infinity;
    for (final e in events) {
      final d = _distanceAlong(LatLng(e.lat, e.lon)) - along;
      if (d < -50 || d > 1200) continue;
      if (d < nearestDist) {
        nearestDist = d;
        nearest = e;
      }
    }
    _upcomingAlert = nearest;
    _upcomingAlertDistance = nearestDist == double.infinity
        ? double.infinity
        : max(0.0, nearestDist);
    if (nearest == null || nearestDist == double.infinity) return;
    final double speakAt;
    switch (nearest.type) {
      case RoadEventType.speedCamera:
        speakAt = 500;
      case RoadEventType.police:
      case RoadEventType.accident:
        speakAt = 1000;
      case RoadEventType.obstacle:
      case RoadEventType.breakdown:
        speakAt = 800;
    }
    if (nearestDist <= speakAt && _spokenAlerts.add(nearest.id)) {
      _speak(NavigationService.shared.alertFor(nearest, nearestDist.round()));
    }
  }

  void _maybeReroute(LatLng real, double realToRoute) {
    if (!mounted || _arrived || _demoMode) return;
    if (realToRoute <= _rerouteThresholdMeters) return;
    final now = DateTime.now();
    if (now.difference(_lastReroute) < _rerouteCooldown) return;
    _lastReroute = now;
    final dest = _route.waypoints.last;
    _doReroute(real, dest, true);
  }

  Future<void> _doReroute(
      LatLng origin, LatLng destination, bool avoidHighways) async {
    if (_rerouting) return;
    setState(() => _rerouting = true);
    try {
      final result = await RoutingService.shared.calculateRoute(
        start: origin,
        end: destination,
        avoidHighways: avoidHighways,
      );
      _handleRerouteResult(origin, result);
    } catch (_) {
      _maybeRerouteFailed();
    }
  }

  void _handleRerouteResult(LatLng origin, MotorcycleRoute? result) {
    if (!mounted) return;
    if (result == null ||
        result.waypoints.length < 2 ||
        _distanceBetween(origin, result.waypoints.first) > 3000) {
      _maybeRerouteFailed();
      return;
    }
    final snappedOrigin = _snapToRoute(origin);
    setState(() {
      _route = result;
      _recomputeRouteCache();
      _spokenStepIndex = -1;
      _spokenAlerts.clear();
      _currentStepIndex = 0;
      _nextStepIndex = _nextMeaningfulStepIndex();
      _simAlong = _distanceAlong(snappedOrigin);
      _currentLocation = origin;
      _remainingDistance = _totalDistance;
      _remainingDuration = PolishTrafficRegulations.shared
          .calculateTravelTime(_route.totalDistance, _route.roadTypes)
          .drivingTime;
      _updateProgress(snappedOrigin);
      _rerouting = false;
    });
    _moveCameraTo(origin);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Wyznaczono objazd — zmieniono trasę'),
      duration: Duration(seconds: 3),
    ));
  }

  void _maybeRerouteFailed() {
    if (!mounted) return;
    setState(() => _rerouting = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Nie udało się wyznaczyć objazdu — trwa nawigacja po starej trasie'),
      duration: Duration(seconds: 3),
    ));
  }

  Future<void> _speak(String text) async {
    if (!mounted) return;
    final settings = context.read<SettingsProvider>();
    if (!settings.audioEnabled || !settings.voiceCommands) return;
    if (kIsWeb) {
      await WebTtsService.shared.speak(text);
    } else {
      if (_tts == null) return;
      try {
        await _tts?.stop();
        await _tts?.speak(text);
      } catch (_) {}
    }
  }

  void _moveCameraTo(LatLng loc) {
    if (!_mapReady) return;
    final now = DateTime.now();
    if (now.difference(_lastCameraMove).inMilliseconds < 80) return;
    _lastCameraMove = now;
    try {
      final zoom = max(_mapController.camera.zoom, 16.0);
      const metersPerDegLat = 111320.0;
      final visibleMetersH = 156543.0 * pow(2, -zoom).toDouble();
      final offsetMeters = visibleMetersH * 0.28;
      final offsetLat = offsetMeters / metersPerDegLat;
      final center = LatLng(loc.latitude + offsetLat, loc.longitude);
      _mapController.move(center, zoom);
    } catch (_) {}
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _simTimer?.cancel();
    _simFallbackTimer?.cancel();
    if (kIsWeb) {
      WebTtsService.shared.stop();
    } else {
      _tts?.stop();
    }
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routeProvider = context.watch<RouteProvider>();
    final events = [
      ...routeProvider.routeCameras,
      ...context.watch<EventsProvider>().events,
    ];
    final speedLimits = routeProvider.routeSpeedLimits;
    final trafficSegments = TrafficService.shared
        .trafficAlongRoute(_route.waypoints, events);
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter:
                    _currentLocation ?? _route.waypoints.first,
                initialZoom: 16,
                onMapReady: () {
                  _mapReady = true;
                  final loc = _currentLocation;
                  if (loc != null) {
                    _moveCameraTo(loc);
                  } else {
                    try {
                      _mapController.fitCamera(CameraFit.coordinates(
                        coordinates: _route.waypoints,
                        padding: const EdgeInsets.fromLTRB(40, 80, 40, 160),
                      ));
                    } catch (_) {}
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.motorcycle.routes',
                  tileProvider:
                      widget.tileProvider ?? NetworkTileProvider(),
                ),
                if (_route.waypoints.length > 1) ...[
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: RouteGeometry.decimate(_route.waypoints, 1200),
                        color: Colors.white,
                        strokeWidth: 6,
                      ),
                      Polyline(
                        points: RouteGeometry.decimate(_route.waypoints, 1200),
                        color: Colors.deepOrange,
                        strokeWidth: 4,
                      ),
                    ],
                  ),
                  if (trafficSegments.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        for (final s in trafficSegments)
                          Polyline(
                            points: s.points,
                            color: trafficSegmentColor(s.severity),
                            strokeWidth: 6,
                          ),
                      ],
                    ),
                  if (events.isNotEmpty)
                    MarkerLayer(
                      markers: [
                        for (final e in events)
                          Marker(
                            point: LatLng(e.lat, e.lon),
                            width: 30,
                            height: 30,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: roadEventColor(e.type), width: 2),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Colors.black38, blurRadius: 4),
                                ],
                              ),
                              child: Icon(eventIcon(e.type),
                                  size: 16, color: roadEventColor(e.type)),
                            ),
                          ),
                      ],
                    ),
                  if (speedLimits.isNotEmpty)
                    MarkerLayer(
                      markers: [
                        for (final sl in speedLimits)
                          Marker(
                            point: sl.nearestPoint,
                            width: 36,
                            height: 36,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.red, width: 2.5),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Colors.black26, blurRadius: 3),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${sl.limit}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _route.waypoints.first,
                        width: 32,
                        height: 32,
                        child: const Icon(Icons.motorcycle,
                            color: Colors.green, size: 28),
                      ),
                      Marker(
                        point: _route.waypoints.last,
                        width: 32,
                        height: 32,
                        child: const Icon(Icons.flag,
                            color: Colors.red, size: 28),
                      ),
                    ],
                  ),
                  if (_route.intermediateWaypoints.isNotEmpty)
                    MarkerLayer(
                      markers: [
                        for (final wp in _route.intermediateWaypoints)
                          Marker(
                            point: wp,
                            width: 34,
                            height: 34,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.blue, width: 2),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Colors.black38, blurRadius: 4),
                                ],
                              ),
                              child:
                                  const Icon(Icons.place, size: 18, color: Colors.blue),
                            ),
                          ),
                      ],
                    ),
                ],
                if (_currentLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentLocation!,
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.deepOrange, width: 2.5),
                            boxShadow: const [
                              BoxShadow(color: Colors.black45, blurRadius: 5),
                            ],
                          ),
                          child: const Icon(Icons.motorcycle,
                              color: Colors.deepOrange, size: 22),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (_currentLocation == null)
            const Positioned.fill(
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Lokalizowanie...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (!_arrived)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              right: 8,
              child: Column(
                children: [
                  _buildInstructionBanner(),
                  if (_upcomingAlert != null && !_rerouting) ...[
                    const SizedBox(height: 8),
                    _buildAlertBanner(),
                  ],
                ],
              ),
            ),
          if (_rerouting)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              right: 8,
              child: Card(
                color: Theme.of(context).colorScheme.surface,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 12),
                      Text('Wyznaczam objazd...',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          if (!_arrived)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomBar(),
            ),
          if (_arrived) Positioned.fill(child: _buildArrivalOverlay()),
        ],
      ),
    );
  }

  Widget _buildInstructionBanner() {
    final steps = _route.steps;
    if (steps.isEmpty) return const SizedBox.shrink();
    final step = steps[_nextStepIndex];
    final instruction = NavigationService.shared.instructionFor(step);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: Row(
        children: [
          Icon(_arrowFor(step), size: 40, color: Colors.deepOrange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(instruction,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  [
                    'za ${_formatDistance(_distanceToNext)}',
                    if (step.name.isNotEmpty) step.name,
                  ].join(' · '),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertBanner() {
    final e = _upcomingAlert;
    if (e == null) return const SizedBox.shrink();
    final color = roadEventColor(e.type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: Row(
        children: [
          Icon(eventIcon(e.type), color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${e.type.label} — '
              '${_upcomingAlertDistance == double.infinity ? '?' : _formatDistance(_upcomingAlertDistance)}',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final remainingKm = _remainingDistance / 1000.0;
    final distText = remainingKm >= 100
        ? '${remainingKm.round()} km'
        : remainingKm >= 10
            ? '${remainingKm.round()} km'
            : '${remainingKm.toStringAsFixed(1)} km';
    final min = (_remainingDuration / 60).round();
    final timeText =
        min >= 60 ? 'ok. ${min ~/ 60}h ${min % 60}min' : 'ok. $min min';
    final arrival = DateTime.now()
        .add(Duration(seconds: _remainingDuration.toInt()));
    final arrivalText = 'Przyjazd ok. '
        '${arrival.hour.toString().padLeft(2, '0')}:'
        '${arrival.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${_currentSpeed.round()} km/h',
                      style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange)),
                  const Text('Prędkość',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                  if (_demoMode)
                    const Text('Tryb demo',
                        style:
                            TextStyle(fontSize: 10, color: Colors.deepOrange)),
                  if (_ttsFailed)
                    const Text('TTS niedostępne',
                        style:
                            TextStyle(fontSize: 10, color: Colors.red)),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Zostało $distText',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(timeText,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(arrivalText,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
              label: const Text('Zakończ'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArrivalOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Card(
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.flag, size: 56, color: Colors.green),
              const SizedBox(height: 12),
              const Text('Dotarłeś do celu!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('${_formatDistance(_remainingDistance)} od celu',
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.check),
                label: const Text('Zakończ nawigację'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _arrowFor(RouteStep step) {
    final m = step.modifier ?? '';
    switch (step.type) {
      case 'depart':
        return Icons.navigation;
      case 'arrive':
        return Icons.flag;
      case 'roundabout':
      case 'rotary':
      case 'exit roundabout':
        return Icons.roundabout_right;
      case 'merge':
        return Icons.merge;
      case 'on ramp':
        return Icons.ramp_right;
      case 'off ramp':
        return Icons.ramp_left;
      case 'fork':
        return m.contains('left') ? Icons.fork_left : Icons.fork_right;
      case 'turn':
      case 'end of road':
      case 'new name':
      case 'continue':
      case 'restricted':
        switch (m) {
          case 'left':
            return Icons.turn_left;
          case 'right':
            return Icons.turn_right;
          case 'slight left':
            return Icons.turn_slight_left;
          case 'slight right':
            return Icons.turn_slight_right;
          case 'sharp left':
            return Icons.turn_sharp_left;
          case 'sharp right':
            return Icons.turn_sharp_right;
          case 'uturn':
            return Icons.u_turn_left;
          case 'straight':
            return Icons.straight;
          default:
            return Icons.straight;
        }
      default:
        return Icons.straight;
    }
  }

  double _distanceAlong(LatLng p) {
    final pts = _route.waypoints;
    if (pts.length < 2) return 0;
    const scale = 111320.0;
    var best = double.infinity;
    var bestAlong = 0.0;
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i];
      final b = pts[i + 1];
      final midLat = (a.latitude + b.latitude) / 2 * pi / 180;
      final cosLat = cos(midLat);
      final ax = a.longitude * cosLat * scale;
      final ay = a.latitude * scale;
      final bx = b.longitude * cosLat * scale;
      final by = b.latitude * scale;
      final px = p.longitude * cosLat * scale;
      final py = p.latitude * scale;
      final dx = bx - ax;
      final dy = by - ay;
      final len2 = dx * dx + dy * dy;
      var t = len2 == 0 ? 0.0 : ((px - ax) * dx + (py - ay) * dy) / len2;
      t = t.clamp(0.0, 1.0);
      final cx = ax + t * dx;
      final cy = ay + t * dy;
      final perp = sqrt(pow(px - cx, 2) + pow(py - cy, 2));
      if (perp < best) {
        best = perp;
        bestAlong =
            _waypointCumulative[i] + sqrt(pow(cx - ax, 2) + pow(cy - ay, 2));
      }
    }
    return bestAlong;
  }

  List<double> _cumulativeDistances(List<LatLng> pts) {
    const r = 6371000.0;
    final cum = <double>[0];
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1];
      final b = pts[i];
      final dLat = (b.latitude - a.latitude) * pi / 180;
      final dLon = (b.longitude - a.longitude) * pi / 180;
      final la1 = a.latitude * pi / 180;
      final la2 = b.latitude * pi / 180;
      final h =
          pow(sin(dLat / 2), 2) + cos(la1) * cos(la2) * pow(sin(dLon / 2), 2);
      final d = 2 * r * asin(sqrt(h));
      cum.add(cum[i - 1] + d);
    }
    return cum;
  }

  List<double> _computeStepCumulative(List<RouteStep> steps) {
    final cum = <double>[];
    var acc = 0.0;
    for (final s in steps) {
      cum.add(acc);
      acc += s.distance;
    }
    return cum;
  }

  String _formatDistance(double meters) {
    final km = meters / 1000.0;
    return km >= 100 ? '${km.round()} km' : '${km.toStringAsFixed(1)} km';
  }
}

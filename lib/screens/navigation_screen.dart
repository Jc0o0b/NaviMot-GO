import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/route.dart';
import '../models/route_step.dart';
import '../models/traffic_regulations.dart';
import '../services/location_service.dart';
import '../services/navigation_service.dart';
import '../widgets/road_view_2d.dart';

class NavigationScreen extends StatefulWidget {
  final MotorcycleRoute route;
  final TileProvider? tileProvider;
  const NavigationScreen({super.key, required this.route, this.tileProvider});

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

  late final List<double> _waypointCumulative;
  late final List<double> _stepCumulative;
  late final double _totalDistance;

  LatLng? _currentLocation;
  double _currentSpeed = 0;
  double _heading = 0;
  int _currentStepIndex = 0;
  int _nextStepIndex = 1;
  double _distanceToNext = 0;
  double _remainingDistance = 0;
  double _remainingDuration = 0;
  int _spokenStepIndex = -1;
  bool _arrived = false;
  bool _mapReady = false;
  DateTime _lastCameraMove = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _waypointCumulative = _cumulativeDistances(widget.route.waypoints);
    _totalDistance = _waypointCumulative.isNotEmpty
        ? _waypointCumulative.last
        : widget.route.totalDistance;
    _stepCumulative = _computeStepCumulative(widget.route.steps);
    _nextStepIndex = _nextMeaningfulStepIndex();
    _remainingDistance = _totalDistance;
    _remainingDuration = PolishTrafficRegulations.shared
        .calculateTravelTime(
            widget.route.totalDistance, widget.route.roadTypes)
        .drivingTime;
    _initTts();
    _startTracking();
  }

  Future<void> _initTts() async {
    try {
      final tts = FlutterTts();
      await tts.setLanguage('pl-PL');
      await tts.setSpeechRate(0.48);
      await tts.setVolume(1.0);
      _tts = tts;
      if (mounted && widget.route.steps.isNotEmpty) {
        final first = widget.route.steps.first;
        if (NavigationService.shared.shouldSpeak(first)) {
          _speak(NavigationService.shared.instructionFor(first));
        }
        _spokenStepIndex = 0;
      }
    } catch (_) {}
  }

  Future<void> _startTracking() async {
    _simFallbackTimer = Timer(const Duration(seconds: 10), _maybeEnterDemo);
    LatLng? location;
    try {
      location = await LocationService.getCurrentLocation();
    } catch (_) {}
    if (location != null && mounted) {
      setState(() => _currentLocation = location);
      _moveCameraTo(location);
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

  void _maybeEnterDemo() {
    if (mounted && _currentLocation == null && !_demoMode) {
      _startSimulation();
    }
  }

  void _startSimulation() {
    final pts = widget.route.waypoints;
    if (pts.isEmpty) return;
    _simTimer?.cancel();
    _demoMode = true;
    _simSpeedMs = 50 / 3.6;
    final loc = _currentLocation ?? pts.first;
    setState(() {
      _currentLocation = loc;
      _simAlong = _waypointCumulative.length > 1 ? _distanceAlong(loc) : 0;
    });
    _moveCameraTo(loc);
    _simTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _advanceSimulation(),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Brak sygnału GPS — uruchomiono tryb demo'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _advanceSimulation() {
    final pts = widget.route.waypoints;
    if (pts.length < 2) return;
    final total = _waypointCumulative.last;
    _simAlong += _simSpeedMs;
    if (_simAlong >= total) {
      _simAlong = total;
      _simTimer?.cancel();
    }
    final loc = _pointAtAlong(_simAlong);
    final ahead = _pointAtAlong(min(_simAlong + 6, total));
    setState(() {
      _currentLocation = loc;
      _currentSpeed = 50 + 5 * sin(_simAlong / 400);
      _heading = _bearing(loc, ahead);
      _updateProgress(loc);
    });
    _moveCameraTo(loc);
    if (_simAlong >= total) {
      setState(() => _arrived = true);
    }
  }

  LatLng _pointAtAlong(double along) {
    final pts = widget.route.waypoints;
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
    if (_demoMode) {
      _simTimer?.cancel();
      _demoMode = false;
    }
    final loc = LatLng(pos.latitude, pos.longitude);
    final speedMs = pos.speed.isFinite ? pos.speed : 0.0;
    final heading = pos.heading.isFinite ? pos.heading : 0.0;
    setState(() {
      _currentLocation = loc;
      _currentSpeed = speedMs > 0.4 ? speedMs * 3.6 : 0;
      _heading = heading;
      _updateProgress(loc);
    });
    _moveCameraTo(loc);
  }

  void _updateProgress(LatLng loc) {
    final steps = widget.route.steps;
    if (steps.isEmpty) {
      _remainingDistance = max(0, _totalDistance - _distanceAlong(loc));
      final totalTravel = PolishTrafficRegulations.shared
          .calculateTravelTime(widget.route.totalDistance,
              widget.route.roadTypes)
          .drivingTime;
      _remainingDuration =
          _totalDistance > 0 ? totalTravel * (_remainingDistance / _totalDistance) : 0;
      return;
    }
    final along = _distanceAlong(loc);
    _remainingDistance = max(0, _totalDistance - along);

    var cs = 0;
    for (var i = 0; i < _stepCumulative.length; i++) {
      if (_stepCumulative[i] <= along + 30) cs = i;
    }
    _currentStepIndex = cs;
    _nextStepIndex = _nextMeaningfulStepIndex();
    _distanceToNext = max(0, _stepCumulative[_nextStepIndex] - along);

    final step = steps[_currentStepIndex];
    final stepLen = step.distance > 0 ? step.distance : 1.0;
    final fracInStep = ((along - _stepCumulative[_currentStepIndex]) / stepLen)
        .clamp(0.0, 1.0);
    var rem = step.duration * (1 - fracInStep);
    for (var i = _currentStepIndex + 1; i < steps.length; i++) {
      rem += steps[i].duration;
    }
    _remainingDuration = max(0, rem);

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
    final steps = widget.route.steps;
    if (steps.isEmpty) return -1;
    for (var i = _currentStepIndex + 1; i < steps.length; i++) {
      if (NavigationService.shared.shouldSpeak(steps[i])) return i;
    }
    return steps.length - 1;
  }

  Future<void> _speak(String text) async {
    try {
      await _tts?.stop();
      await _tts?.speak(text);
    } catch (_) {}
  }

  void _moveCameraTo(LatLng loc) {
    if (!_mapReady) return;
    final now = DateTime.now();
    if (now.difference(_lastCameraMove).inMilliseconds < 900) return;
    _lastCameraMove = now;
    try {
      _mapController.move(loc, max(_mapController.camera.zoom, 16));
    } catch (_) {}
  }

  List<LatLng> _remainingPath() {
    final loc = _currentLocation;
    final pts = widget.route.waypoints;
    if (loc == null || pts.length < 2) return const [];
    final seg = _nearestSegmentIndex(loc);
    final projected = _projectOnSegment(loc, pts[seg], pts[seg + 1]);
    final list = <LatLng>[projected];
    final step = max(1, (pts.length - seg - 1) ~/ 70);
    for (var i = seg + 1; i < pts.length; i += step) {
      list.add(pts[i]);
      if (list.length >= 70) break;
    }
    if (!identical(list.last, pts.last)) list.add(pts.last);
    return list;
  }

  double _effectiveHeading() {
    if (_heading != 0) return _heading;
    final path = _remainingPath();
    if (path.length > 1) return _bearing(path[0], path[1]);
    return 0;
  }

  double _bearing(LatLng a, LatLng b) {
    final la1 = a.latitude * pi / 180;
    final la2 = b.latitude * pi / 180;
    final dLon = (b.longitude - a.longitude) * pi / 180;
    final y = sin(dLon) * cos(la2);
    final x = cos(la1) * sin(la2) - sin(la1) * cos(la2) * cos(dLon);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _simTimer?.cancel();
    _simFallbackTimer?.cancel();
    _tts?.stop();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                Container(
                  height: 150,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDCE7D0),
                    border: Border(
                      bottom: BorderSide(color: Colors.black12),
                    ),
                  ),
                  child: RoadView2D(
                    path: _remainingPath(),
                    headingDeg: _effectiveHeading(),
                  ),
                ),
                Expanded(
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter:
                          _currentLocation ?? widget.route.waypoints.first,
                      initialZoom: 15,
                      onMapReady: () {
                        _mapReady = true;
                        final loc = _currentLocation;
                        if (loc != null) {
                          _moveCameraTo(loc);
                        } else {
                          try {
                            _mapController.fitCamera(CameraFit.coordinates(
                              coordinates: widget.route.waypoints,
                              padding: const EdgeInsets.all(10),
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
                      if (widget.route.waypoints.length > 1) ...[
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: widget.route.waypoints,
                              color: Colors.white,
                              strokeWidth: 6,
                            ),
                            Polyline(
                              points: widget.route.waypoints,
                              color: Colors.deepOrange,
                              strokeWidth: 4,
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: widget.route.waypoints.first,
                              width: 32,
                              height: 32,
                              child: const Icon(Icons.motorcycle,
                                  color: Colors.green, size: 28),
                            ),
                            Marker(
                              point: widget.route.waypoints.last,
                              width: 32,
                              height: 32,
                              child: const Icon(Icons.flag,
                                  color: Colors.red, size: 28),
                            ),
                          ],
                        ),
                      ],
                      if (_currentLocation != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _currentLocation!,
                              width: 30,
                              height: 30,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 2),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Colors.black38, blurRadius: 4)
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
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
              child: _buildInstructionBanner(),
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
    final steps = widget.route.steps;
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
                if (step.name.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(step.name,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ],
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
    final pts = widget.route.waypoints;
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

  int _nearestSegmentIndex(LatLng p) {
    final pts = widget.route.waypoints;
    const scale = 111320.0;
    final cosLat = cos(p.latitude * pi / 180);
    var best = double.infinity;
    var bestIdx = 0;
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i];
      final b = pts[i + 1];
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
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  LatLng _projectOnSegment(LatLng p, LatLng a, LatLng b) {
    const scale = 111320.0;
    final cosLat = cos(p.latitude * pi / 180);
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
    return LatLng((ay + t * dy) / scale, (ax + t * dx) / (scale * cosLat));
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

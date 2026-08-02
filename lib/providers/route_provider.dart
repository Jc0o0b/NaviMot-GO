import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/route.dart';
import '../models/route_options.dart';
import '../models/traffic_regulations.dart';
import '../services/routing_service.dart';
import '../services/location_service.dart';
import '../utils/scenic_route_calculator.dart';

class RouteProvider extends ChangeNotifier {
  static const String _savedRoutesKey = 'saved_routes';

  MotorcycleRoute? _currentRoute;
  RouteOptions _routeOptions = RouteOptions();
  bool _isLoading = false;
  String? _errorMessage;
  List<MotorcycleRoute> _savedRoutes = [];
  List<MotorcycleRoute> _routeAlternatives = [];
  TravelTimeInfo? _travelTimeInfo;
  LatLng? _startLocation;
  LatLng? _endLocation;
  List<LatLng> _intermediateWaypoints = [];

  RouteProvider() {
    _loadSavedRoutes();
  }

  MotorcycleRoute? get currentRoute => _currentRoute;
  RouteOptions get routeOptions => _routeOptions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<MotorcycleRoute> get savedRoutes => _savedRoutes;
  List<MotorcycleRoute> get routeAlternatives => List.unmodifiable(_routeAlternatives);
  TravelTimeInfo? get travelTimeInfo => _travelTimeInfo;
  LatLng? get startLocation => _startLocation;
  LatLng? get endLocation => _endLocation;
  List<LatLng> get intermediateWaypoints => List.unmodifiable(_intermediateWaypoints);

  void addWaypoint(LatLng loc) {
    final exists = _intermediateWaypoints.any((w) =>
        (w.latitude - loc.latitude).abs() < 0.0001 &&
        (w.longitude - loc.longitude).abs() < 0.0001);
    if (!exists) _intermediateWaypoints.add(loc);
    _replan();
  }

  void removeWaypoint(LatLng loc) {
    _intermediateWaypoints.removeWhere((w) =>
        (w.latitude - loc.latitude).abs() < 0.0001 &&
        (w.longitude - loc.longitude).abs() < 0.0001);
    _replan();
  }

  void _replan() {
    notifyListeners();
    final start = _startLocation;
    final end = _endLocation;
    if (start != null && end != null && _currentRoute != null) {
      planRoute(start, end);
    }
  }

  void planRoute(LatLng start, LatLng end) async {
    _isLoading = true;
    _errorMessage = null;
    _routeAlternatives = [];
    notifyListeners();

    try {
      final plainWaypoints = List<LatLng>.from(_intermediateWaypoints);
      var scenicWaypoints = List<LatLng>.from(_intermediateWaypoints);

      if (_routeOptions.includeScenicDetours) {
        final tempRoute = await RoutingService.shared.calculateRoute(
          start: start,
          end: end,
          waypoints: scenicWaypoints,
          avoidHighways: true,
        );
        final detour = ScenicRouteCalculator.shared.suggestScenicDetour(tempRoute);
        if (detour != null) scenicWaypoints.addAll(detour);
      }

      final alternatives = await RoutingService.shared.calculateAlternatives(
        start: start,
        end: end,
        waypoints: plainWaypoints,
        scenicWaypoints: scenicWaypoints,
      );

      _routeAlternatives = alternatives;
      _currentRoute = _routeOptions.avoidHighways ? alternatives[0] : alternatives[1];
      _travelTimeInfo = PolishTrafficRegulations.shared.calculateTravelTime(
        _currentRoute!.totalDistance,
        _currentRoute!.roadTypes,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Nie udało się wyznaczyć trasy: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectRoute(MotorcycleRoute route) {
    _currentRoute = route;
    _travelTimeInfo = PolishTrafficRegulations.shared.calculateTravelTime(
      route.totalDistance,
      route.roadTypes,
    );
    notifyListeners();
  }

  Future<void> useCurrentLocation() async {
    final location = await LocationService.getCurrentLocation();
    if (location != null) {
      _startLocation = location;
      _routeOptions.startLocation = location;
      notifyListeners();
    } else {
      _errorMessage = 'Nie udało się pobrać lokalizacji';
      notifyListeners();
    }
  }

  void saveRoute(MotorcycleRoute route) {
    if (!_savedRoutes.any((r) => r.id == route.id)) {
      _savedRoutes.add(route);
      notifyListeners();
      _persistSavedRoutes();
    }
  }

  void deleteRoute(MotorcycleRoute route) {
    _savedRoutes.removeWhere((r) => r.id == route.id);
    notifyListeners();
    _persistSavedRoutes();
  }

  Future<void> _loadSavedRoutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_savedRoutesKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        _savedRoutes = list
            .map((e) => MotorcycleRoute.fromJson(e as Map<String, dynamic>))
            .toList();
        notifyListeners();
      }
    } catch (_) {
      _savedRoutes = [];
    }
  }

  Future<void> _persistSavedRoutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _savedRoutesKey,
        jsonEncode(_savedRoutes.map((r) => r.toJson()).toList()),
      );
    } catch (_) {}
  }

  void setRouteOptions(RouteOptions options) {
    _routeOptions = options;
    notifyListeners();
  }

  void setStartLocation(LatLng? loc) {
    _startLocation = loc;
    _routeOptions.startLocation = loc;
    notifyListeners();
  }

  void setEndLocation(LatLng? loc) {
    _endLocation = loc;
    _routeOptions.endLocation = loc;
    notifyListeners();
  }
}

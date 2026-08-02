import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/route.dart';
import '../models/route_options.dart';
import '../models/traffic_regulations.dart';
import '../services/routing_service.dart';
import '../services/location_service.dart';
import '../utils/scenic_route_calculator.dart';

class RouteProvider extends ChangeNotifier {
  MotorcycleRoute? _currentRoute;
  RouteOptions _routeOptions = RouteOptions();
  bool _isLoading = false;
  String? _errorMessage;
  List<MotorcycleRoute> _savedRoutes = [];
  TravelTimeInfo? _travelTimeInfo;
  LatLng? _startLocation;
  LatLng? _endLocation;
  List<LatLng> _intermediateWaypoints = [];

  MotorcycleRoute? get currentRoute => _currentRoute;
  RouteOptions get routeOptions => _routeOptions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<MotorcycleRoute> get savedRoutes => _savedRoutes;
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
    notifyListeners();

    try {
      var waypoints = List<LatLng>.from(_intermediateWaypoints);

      if (_routeOptions.includeScenicDetours) {
        final tempRoute = await RoutingService.shared.calculateRoute(
          start: start,
          end: end,
          waypoints: waypoints,
          avoidHighways: _routeOptions.avoidHighways,
        );
        final detour = ScenicRouteCalculator.shared.suggestScenicDetour(tempRoute);
        if (detour != null) waypoints.addAll(detour);
      }

      final route = await RoutingService.shared.calculateRoute(
        start: start,
        end: end,
        waypoints: waypoints,
        avoidHighways: _routeOptions.avoidHighways,
      );

      _currentRoute = route;
      _travelTimeInfo = PolishTrafficRegulations.shared.calculateTravelTime(
        route.totalDistance,
        route.roadTypes,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Nie udało się wyznaczyć trasy: $e';
      _isLoading = false;
      notifyListeners();
    }
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
    }
  }

  void deleteRoute(MotorcycleRoute route) {
    _savedRoutes.removeWhere((r) => r.id == route.id);
    notifyListeners();
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

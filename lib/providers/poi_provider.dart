import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/route.dart';
import '../models/point_of_interest.dart';
import '../services/poi_service.dart';

class POIProvider extends ChangeNotifier {
  List<PointOfInterest> _pointsOfInterest = [];
  bool _isLoading = false;
  String? _errorMessage;
  POICategory? _selectedCategory;
  PointOfInterest? _selectedPOI;

  List<PointOfInterest> get pointsOfInterest => _pointsOfInterest;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  POICategory? get selectedCategory => _selectedCategory;
  PointOfInterest? get selectedPOI => _selectedPOI;

  void loadPOIs(MotorcycleRoute route, {double radius = 10000}) {
    if (route.waypoints.isEmpty) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    POIService.shared.fetchPOIsAlongRoute(route.waypoints, radius: radius).then((pois) {
      _pointsOfInterest = pois;
      _isLoading = false;
      notifyListeners();
    }).catchError((e) {
      _errorMessage = 'Nie udało się pobrać miejsc: $e';
      _isLoading = false;
      notifyListeners();
    });
  }

  void loadPOIsNear(LatLng coordinate) {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    POIService.shared.fetchPOIsNearLocation(coordinate, category: _selectedCategory).then((pois) {
      _pointsOfInterest = pois;
      _isLoading = false;
      notifyListeners();
    }).catchError((e) {
      _errorMessage = 'Nie udało się pobrać miejsc: $e';
      _isLoading = false;
      notifyListeners();
    });
  }

  List<PointOfInterest> get filteredPOIs {
    if (_selectedCategory == null) return _pointsOfInterest;
    return _pointsOfInterest.where((p) => p.category == _selectedCategory).toList();
  }

  Map<POICategory, List<PointOfInterest>> get categorizedPOIs {
    final map = <POICategory, List<PointOfInterest>>{};
    for (final poi in _pointsOfInterest) {
      map.putIfAbsent(poi.category, () => []).add(poi);
    }
    return map;
  }

  List<MapEntry<POICategory, int>> get categoryCounts {
    final grouped = categorizedPOIs;
    return POICategory.values
      .map((c) => MapEntry(c, grouped[c]?.length ?? 0))
      .where((e) => e.value > 0)
      .toList();
  }

  void selectCategory(POICategory? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void selectPOI(PointOfInterest? poi) {
    _selectedPOI = poi;
    notifyListeners();
  }
}

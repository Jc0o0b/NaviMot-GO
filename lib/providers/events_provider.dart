import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/important_place.dart';
import '../models/road_event.dart';

class EventsProvider extends ChangeNotifier {
  static const String _eventsKey = 'road_events';
  static const String _placesKey = 'important_places';

  List<RoadEvent> _events = [];
  List<ImportantPlace> _places = [];
  bool _loaded = false;
  Future<void>? _loadFuture;

  List<RoadEvent> get events => List.unmodifiable(_events);
  List<ImportantPlace> get importantPlaces => List.unmodifiable(_places);
  bool get isLoaded => _loaded;

  EventsProvider() {
    load();
  }

  Future<void> load() {
    return _loadFuture ??= _doLoad();
  }

  Future<void> _doLoad() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _events = _readEvents(prefs);
      _places = _readPlaces(prefs);
    } catch (_) {
      _events = [];
      _places = [];
    }
    _loaded = true;
    notifyListeners();
  }

  List<RoadEvent> _readEvents(SharedPreferences prefs) {
    final raw = prefs.getString(_eventsKey);
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List)
        .map((e) => RoadEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  List<ImportantPlace> _readPlaces(SharedPreferences prefs) {
    final raw = prefs.getString(_placesKey);
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List)
        .map((e) => ImportantPlace.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addRoadEvent({
    required RoadEventType type,
    required LatLng location,
    String? description,
  }) async {
    _events.insert(
      0,
      RoadEvent(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: type,
        lat: location.latitude,
        lon: location.longitude,
        description: description,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
    await _persistEvents();
  }

  Future<void> removeRoadEvent(String id) async {
    _events.removeWhere((e) => e.id == id);
    notifyListeners();
    await _persistEvents();
  }

  Future<void> addImportantPlace({
    required String name,
    required String note,
    String? photoBase64,
    required LatLng location,
  }) async {
    _places.insert(
      0,
      ImportantPlace(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        note: note,
        photoBase64: photoBase64,
        lat: location.latitude,
        lon: location.longitude,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
    await _persistPlaces();
  }

  Future<void> removeImportantPlace(String id) async {
    _places.removeWhere((p) => p.id == id);
    notifyListeners();
    await _persistPlaces();
  }

  Future<void> _persistEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _eventsKey,
        jsonEncode(_events.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> _persistPlaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _placesKey,
        jsonEncode(_places.map((p) => p.toJson()).toList()),
      );
    } catch (_) {}
  }
}

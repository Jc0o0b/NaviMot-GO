import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/important_place.dart';
import '../models/road_event.dart';
import '../models/user_profile.dart';
import 'account_provider.dart';
import '../services/community_service.dart';

/// Wynik próby potwierdzenia zdarzenia.
enum ConfirmResult { ok, already, notSignedIn, notFound }

class EventsProvider extends ChangeNotifier {
  static const String _placesKey = 'important_places';

  final CommunityService _community;
  final AccountProvider? _account;

  EventsProvider({CommunityService? community, AccountProvider? account})
      : _community = community ?? LocalCommunityService(),
        _account = account;

  List<RoadEvent> _events = [];
  List<ImportantPlace> _places = [];
  bool _loaded = false;
  Future<void>? _loadFuture;

  // Zwracamy listy bezpośrednio (bez List.unmodifiable) — porównania
  // tożsamości w cache'ach widgetów muszą trafiać.
  List<RoadEvent> get events => _events;
  List<ImportantPlace> get importantPlaces => _places;
  bool get isLoaded => _loaded;

  bool get _isSignedIn => _account?.isSignedIn ?? false;

  Future<void> load() {
    return _loadFuture ??= _doLoad();
  }

  Future<void> _doLoad() async {
    try {
      _events = await _community.fetchEvents();
    } catch (_) {
      _events = [];
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      _places = _readPlaces(prefs);
    } catch (_) {
      _places = [];
    }
    _loaded = true;
    notifyListeners();
  }

  List<ImportantPlace> _readPlaces(SharedPreferences prefs) {
    final raw = prefs.getString(_placesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map((e) {
            try {
              return ImportantPlace.fromJson(e);
            } catch (_) {
              return null;
            }
          })
          .whereType<ImportantPlace>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<RoadEvent> addRoadEvent({
    required RoadEventType type,
    required LatLng location,
    String? description,
    int? speedLimit,
  }) async {
    final reporterId = _account?.user?.uid;
    final event = RoadEvent(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: type,
      lat: location.latitude,
      lon: location.longitude,
      description: description,
      createdAt: DateTime.now(),
      speedLimit: speedLimit,
      reporterId: reporterId,
    );
    _events.insert(0, event);
    notifyListeners();
    await _community.saveEvents(_events);
    if (_isSignedIn) {
      await _account?.award(points: PointsRules.report, report: true);
    }
    return event;
  }

  /// Potwierdza zdarzenie (jeden użytkownik może potwierdzić raz).
  Future<ConfirmResult> confirmRoadEvent(String eventId) async {
    final uid = _account?.user?.uid;
    if (uid == null) return ConfirmResult.notSignedIn;
    final idx = _events.indexWhere((e) => e.id == eventId);
    if (idx == -1) return ConfirmResult.notFound;
    final confirmed = await _community.confirmationsFor(eventId);
    if (confirmed.contains(uid)) return ConfirmResult.already;
    await _community.saveConfirmation(eventId, uid);
    _events[idx] =
        _events[idx].copyWith(confirmations: _events[idx].confirmations + 1);
    notifyListeners();
    await _community.saveEvents(_events);
    await _account?.award(
        points: PointsRules.confirmation, confirmation: true);
    return ConfirmResult.ok;
  }

  Future<void> removeRoadEvent(String id) async {
    _events.removeWhere((e) => e.id == id);
    notifyListeners();
    await _community.saveEvents(_events);
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
    if (_isSignedIn) {
      await _account?.award(points: PointsRules.placeAdded, place: true);
    }
  }

  Future<void> removeImportantPlace(String id) async {
    _places.removeWhere((p) => p.id == id);
    notifyListeners();
    await _persistPlaces();
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

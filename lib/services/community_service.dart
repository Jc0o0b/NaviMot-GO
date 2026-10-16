import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/road_event.dart';

/// Abstrakcja wspólnej bazy zdarzeń drogowych i ich potwierdzeń.
/// Dziś działa implementacja lokalna ([LocalCommunityService]); docelowo
/// podmieniana na Firestore bez zmian w resztce aplikacji.
abstract class CommunityService {
  /// Czy usługa korzysta ze zdalnego backendu (Firebase/Firestore).
  bool get isRemote;

  Future<List<RoadEvent>> fetchEvents();
  Future<void> saveEvents(List<RoadEvent> events);

  /// Użytkownicy, którzy już potwierdzili dane zdarzenie.
  Future<Set<String>> confirmationsFor(String eventId);

  /// Zapisuje potwierdzenie zdarzenia przez użytkownika.
  Future<void> saveConfirmation(String eventId, String uid);

  Future<void> deleteEvent(String eventId);
}

/// Lokalna implementacja — zdarzenia i potwierdzenia w SharedPreferences.
/// Na jednym urządzeniu pełni rolę „wspólnej" bazy; po podłączeniu Firebase
/// zostanie zastąpiona przez Firestore.
class LocalCommunityService implements CommunityService {
  static const String _eventsKey = 'community_events';
  static const String _confirmKey = 'community_confirmations';
  static const String _legacyEventsKey = 'road_events';

  @override
  bool get isRemote => false;

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<List<RoadEvent>> fetchEvents() async {
    final prefs = await _prefs;
    var raw = prefs.getString(_eventsKey);
    if ((raw == null || raw.isEmpty)) {
      // Migracja ze starego klucza (zdarzenia użytkownika sprzed Fazy 2).
      final legacy = prefs.getString(_legacyEventsKey);
      if (legacy != null && legacy.isNotEmpty) {
        raw = legacy;
        await prefs.setString(_eventsKey, legacy);
      }
    }
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map((e) {
            try {
              return RoadEvent.fromJson(e);
            } catch (_) {
              return null;
            }
          })
          .whereType<RoadEvent>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveEvents(List<RoadEvent> events) async {
    try {
      final prefs = await _prefs;
      await prefs.setString(
        _eventsKey,
        jsonEncode(events.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  @override
  Future<Set<String>> confirmationsFor(String eventId) async {
    final all = await _readConfirmations();
    return (all[eventId] as List?)?.whereType<String>().toSet() ?? <String>{};
  }

  Future<Map<String, dynamic>> _readConfirmations() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_confirmKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> saveConfirmation(String eventId, String uid) async {
    try {
      final all = await _readConfirmations();
      final list = (all[eventId] as List?)?.whereType<String>().toList() ?? [];
      if (!list.contains(uid)) list.add(uid);
      all[eventId] = list;
      final prefs = await _prefs;
      await prefs.setString(_confirmKey, jsonEncode(all));
    } catch (_) {}
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    final events = await fetchEvents();
    events.removeWhere((e) => e.id == eventId);
    await saveEvents(events);
  }
}

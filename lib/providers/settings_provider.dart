import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/home_address.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _homeKey = 'home_address';

  HomeAddress? _home;
  bool _loaded = false;

  HomeAddress? get home => _home;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_homeKey);
      if (raw != null) {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        _home = HomeAddress.fromJson(json);
      }
    } catch (_) {
      _home = null;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setHome(HomeAddress home) async {
    _home = home;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_homeKey, jsonEncode(home.toJson()));
    } catch (_) {}
    notifyListeners();
  }

  Future<void> clearHome() async {
    _home = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_homeKey);
    } catch (_) {}
    notifyListeners();
  }
}

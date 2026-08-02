import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/home_address.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _homeKey = 'home_address';
  static const String _darkKey = 'dark_mode';
  static const String _nicknameKey = 'nickname';

  HomeAddress? _home;
  bool _loaded = false;
  bool _darkMode = false;
  String _nickname = 'Motocyklista';

  HomeAddress? get home => _home;
  bool get isLoaded => _loaded;
  bool get darkMode => _darkMode;
  String get nickname => _nickname;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_homeKey);
      if (raw != null) {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        _home = HomeAddress.fromJson(json);
      }
      _darkMode = prefs.getBool(_darkKey) ?? false;
      _nickname = prefs.getString(_nicknameKey) ?? 'Motocyklista';
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

  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_darkKey, value);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setNickname(String value) async {
    final trimmed = value.trim();
    _nickname = trimmed.isEmpty ? 'Motocyklista' : trimmed;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_nicknameKey, _nickname);
    } catch (_) {}
    notifyListeners();
  }
}

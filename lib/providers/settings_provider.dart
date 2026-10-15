import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/home_address.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _homeKey = 'home_address';
  static const String _darkKey = 'dark_mode';
  static const String _nicknameKey = 'nickname';
  static const String _audioKey = 'audio_enabled';
  static const String _voiceKey = 'voice_commands';
  static const String _keepScreenKey = 'keep_screen_on';
  static const String _highContrastKey = 'high_contrast';
  static const String _bigNavFontKey = 'big_nav_font';

  HomeAddress? _home;
  bool _loaded = false;
  bool _darkMode = false;
  String _nickname = 'Motocyklista';
  bool _audioEnabled = true;
  bool _voiceCommands = true;
  bool _keepScreenOn = true;
  bool _highContrast = false;
  bool _bigNavFont = false;

  HomeAddress? get home => _home;
  bool get isLoaded => _loaded;
  bool get darkMode => _darkMode;
  String get nickname => _nickname;
  bool get audioEnabled => _audioEnabled;
  bool get voiceCommands => _voiceCommands;
  bool get keepScreenOn => _keepScreenOn;
  bool get highContrast => _highContrast;
  bool get bigNavFont => _bigNavFont;

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
      _audioEnabled = prefs.getBool(_audioKey) ?? true;
      _voiceCommands = prefs.getBool(_voiceKey) ?? true;
      _keepScreenOn = prefs.getBool(_keepScreenKey) ?? true;
      _highContrast = prefs.getBool(_highContrastKey) ?? false;
      _bigNavFont = prefs.getBool(_bigNavFontKey) ?? false;
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

  Future<void> setAudioEnabled(bool value) async {
    _audioEnabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_audioKey, value);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setVoiceCommands(bool value) async {
    _voiceCommands = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_voiceKey, value);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setKeepScreenOn(bool value) async {
    _keepScreenOn = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keepScreenKey, value);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setHighContrast(bool value) async {
    _highContrast = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_highContrastKey, value);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setBigNavFont(bool value) async {
    _bigNavFont = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_bigNavFontKey, value);
    } catch (_) {}
    notifyListeners();
  }
}

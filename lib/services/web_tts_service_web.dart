import 'dart:js_interop';

import 'package:flutter/foundation.dart';

import 'web_tts_service.dart';

WebTtsService createWebTts() => _WebTtsImpl();

@JS('navimotTTS')
external JSObject? get _navimotTts;

@JS('navimotTTS.init')
external JSBoolean _navimotTtsInit();

@JS('navimotTTS.speak')
external void _navimotTtsSpeak(JSString text);

@JS('navimotTTS.stop')
external void _navimotTtsStop();

class _WebTtsImpl implements WebTtsService {
  bool _supported = false;
  bool _activated = false;
  String? lastError;

  @override
  bool get isSupported => _supported;

  @override
  bool get needsUserGesture => _supported && !_activated;

  @override
  Future<void> init() async {
    try {
      if (_navimotTts == null) {
        _supported = false;
        debugPrint('[TTS] init FAILED: navimotTTS not found on window');
        return;
      }
      _supported = _navimotTtsInit().toDart;
      debugPrint('[TTS] init: supported=$_supported');
    } catch (e) {
      lastError = 'init: $e';
      _supported = false;
      debugPrint('[TTS] init FAILED: $e');
    }
  }

  @override
  Future<void> activate() async {
    if (!_supported || _activated) return;
    _activated = true;
  }

  @override
  Future<void> speak(String text) async {
    if (!_supported) return;
    try {
      _navimotTtsSpeak(text.toJS);
      lastError = null;
    } catch (e) {
      lastError = 'speak: $e';
      debugPrint('[TTS] speak FAILED: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      _navimotTtsStop();
    } catch (_) {}
  }
}

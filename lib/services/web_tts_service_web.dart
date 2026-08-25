import 'dart:js_interop';

import 'web_tts_service.dart';

WebTtsService createWebTts() => _WebTtsImpl();

@JS('navimotTTS')
external JSObject? get _navimotTTS;

@JS('navimotTTS.init')
external JSBoolean _navimotTTS_init();

@JS('navimotTTS.speak')
external void _navimotTTS_speak(JSString text);

@JS('navimotTTS.stop')
external void _navimotTTS_stop();

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
      if (_navimotTTS == null) {
        _supported = false;
        print('[TTS] init FAILED: navimotTTS not found on window');
        return;
      }
      _supported = _navimotTTS_init().toDart;
      print('[TTS] init: supported=$_supported');
    } catch (e) {
      lastError = 'init: $e';
      _supported = false;
      print('[TTS] init FAILED: $e');
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
      _navimotTTS_speak(text.toJS);
      lastError = null;
    } catch (e) {
      lastError = 'speak: $e';
      print('[TTS] speak FAILED: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      _navimotTTS_stop();
    } catch (_) {}
  }
}

import 'dart:js_interop';
import 'package:web/web.dart' as web;

import 'web_tts_service.dart';

WebTtsService createWebTts() => _WebTtsImpl();

class _WebTtsImpl implements WebTtsService {
  web.SpeechSynthesis? _synth;
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
      _synth = web.window.speechSynthesis;
      _supported = true;
    } catch (e) {
      lastError = 'init: $e';
      _supported = false;
    }
  }

  @override
  Future<void> activate() async {
    if (!_supported || _synth == null || _activated) return;
    try {
      _synth!.cancel();
      final u = web.SpeechSynthesisUtterance(' ');
      u.lang = 'pl-PL';
      u.volume = 0.0;
      u.rate = 1.0;
      u.pitch = 1.0;
      _synth!.speak(u);
      _activated = true;
    } catch (e) {
      lastError = 'activate: $e';
    }
  }

  @override
  Future<void> speak(String text) async {
    if (!_supported || _synth == null) return;
    try {
      _synth!.cancel();
      final u = web.SpeechSynthesisUtterance(text);
      u.lang = 'pl-PL';
      u.rate = 1.0;
      u.volume = 1.0;
      u.pitch = 1.0;
      try {
        final voices = _synth!.getVoices();
        for (var i = 0; i < voices.length; i++) {
          final v = voices[i];
          if (v.lang.toLowerCase().startsWith('pl')) {
            u.voice = v;
            break;
          }
        }
      } catch (_) {}
      _synth!.speak(u);
      lastError = null;
    } catch (e) {
      lastError = 'speak: $e';
    }
  }

  @override
  Future<void> stop() async {
    try {
      _synth?.cancel();
    } catch (_) {}
  }
}

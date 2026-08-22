import 'dart:js_interop';

import 'web_tts_service.dart';

WebTtsService createWebTts() => _WebTtsImpl();

@JS('speechSynthesis')
external SpeechSynthesis _getSynth();

@JS()
extension type SpeechSynthesis._(JSObject _) implements JSObject {
  external void cancel();
  external JSArray<SpeechSynthesisVoice> getVoices();
  external void pause();
  external void resume();
  external void speak(SpeechSynthesisUtterance utterance);
}

@JS()
extension type SpeechSynthesisUtterance._(JSObject _) implements JSObject {
  external SpeechSynthesisUtterance();
  external String lang;
  external double pitch;
  external double rate;
  external String text;
  external SpeechSynthesisVoice? voice;
  external double volume;

  @JS('onstart')
  external set onStart(JSFunction listener);
  @JS('onend')
  external set onEnd(JSFunction listener);
  @JS('onerror')
  external set onError(JSFunction listener);
}

@JS()
extension type SpeechSynthesisVoice._(JSObject _) implements JSObject {
  @JS('default')
  external bool get isDefault;
  external String get lang;
  @JS('localService')
  external bool get isLocalService;
  external String get name;
}

class _WebTtsImpl implements WebTtsService {
  SpeechSynthesis? _synth;
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
      final s = _getSynth();
      _synth = s;
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
      final u = SpeechSynthesisUtterance();
      u.text = ' ';
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
      final u = SpeechSynthesisUtterance();
      u.text = text;
      u.lang = 'pl-PL';
      u.rate = 1.0;
      u.volume = 1.0;
      u.pitch = 1.0;
      final voices = _synth!.getVoices().toDart;
      for (final v in voices) {
        if (v.lang.toLowerCase().startsWith('pl')) {
          u.voice = v;
          break;
        }
      }
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

import 'web_tts_service.dart';

WebTtsService createWebTts() => _StubWebTts();

class _StubWebTts implements WebTtsService {
  @override
  bool get isSupported => false;

  @override
  bool get needsUserGesture => false;

  @override
  Future<void> init() async {}

  @override
  Future<void> activate() async {}

  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}
}

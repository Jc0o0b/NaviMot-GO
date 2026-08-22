import 'web_tts_service_stub.dart'
    if (dart.library.js_interop) 'web_tts_service_web.dart';

abstract class WebTtsService {
  static WebTtsService? _instance;
  static WebTtsService get shared => _instance ??= createWebTts();
  bool get isSupported;
  bool get needsUserGesture;
  Future<void> init();
  Future<void> activate();
  Future<void> speak(String text);
  Future<void> stop();
}

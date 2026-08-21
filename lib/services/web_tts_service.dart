import 'web_tts_service_stub.dart'
    if (dart.library.js_interop) 'web_tts_service_web.dart';

abstract class WebTtsService {
  static WebTtsService? _instance;
  static WebTtsService get shared => _instance ??= createWebTts();
  bool get isSupported;
  Future<void> init();
  Future<void> speak(String text);
  Future<void> stop();
}

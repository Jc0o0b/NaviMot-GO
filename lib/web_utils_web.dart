import 'package:web/web.dart' as web;

void removeWebSplash() {
  web.document.getElementById('app-splash')?.remove();
}

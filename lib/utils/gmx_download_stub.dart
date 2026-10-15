import 'package:flutter/services.dart';

import '../models/route.dart';
import 'gmx_builder.dart';

/// Platformy mobilne/desktop nie mają dostępu do pobierania plików z
/// przeglądarki, więc zamiast pliku udostępniamy link GPX w schowku.
Future<bool> downloadGmx(MotorcycleRoute route) async {
  await Clipboard.setData(ClipboardData(text: GmxBuilder.linkUri(route)));
  return false;
}

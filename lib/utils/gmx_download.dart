import 'package:flutter/services.dart';

import '../models/route.dart';
import 'gmx_builder.dart';
export 'gmx_download_stub.dart'
    if (dart.library.js_interop) 'gmx_download_web.dart';

String gmxLinkUri(MotorcycleRoute route) => GmxBuilder.linkUri(route);

Future<void> copyGmxLink(MotorcycleRoute route) async {
  await Clipboard.setData(ClipboardData(text: gmxLinkUri(route)));
}

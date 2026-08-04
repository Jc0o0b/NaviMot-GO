import 'dart:js_interop';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;
import '../models/route.dart';
import 'gmx_builder.dart';

void downloadGmx(MotorcycleRoute route) {
  final content = GmxBuilder.buildGmx(route);
  final blob = web.Blob(
    [content.toJS].toJS,
    web.BlobPropertyBag(type: 'application/gpx+xml'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download =
        '${route.name.replaceAll(RegExp(r'[^\wąćęłńóśźżĄĆĘŁŃÓŚŹŻ-]'), '_')}.gmx';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}

String gmxLinkUri(MotorcycleRoute route) => GmxBuilder.linkUri(route);

Future<void> copyGmxLink(MotorcycleRoute route) async {
  await Clipboard.setData(ClipboardData(text: gmxLinkUri(route)));
}

import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../models/route.dart';
import 'gmx_builder.dart';

Future<bool> downloadGmx(MotorcycleRoute route) async {
  final content = GmxBuilder.buildGmx(route);
  final blob = web.Blob(
    [content.toJS].toJS,
    web.BlobPropertyBag(type: 'application/gpx+xml'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download =
        '${route.name.replaceAll(RegExp(r'[^\wąćęłńóśźżĄĆĘŁŃÓŚŹŻ-]'), '_')}.gpx';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return true;
}

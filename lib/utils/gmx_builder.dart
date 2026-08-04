import 'package:latlong2/latlong.dart';
import '../models/route.dart';

class GmxBuilder {
  static const String _namespace = 'http://www.topografix.com/GPX/1/0';

  static String buildGmx(MotorcycleRoute route) {
    final pts = _decimate(route.waypoints);
    final buf = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln(
          '<gpx xmlns="$_namespace" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"')
      ..writeln(
          '  xsi:schemaLocation="$_namespace http://www.topografix.com/GPX/1/0/gpx.xsd"')
      ..writeln('  version="1.0" creator="NaviMot GO">');

    buf.writeln(_waypoint(pts.first, 'Start'));
    for (var i = 1; i < pts.length - 1; i++) {
      buf.writeln(_waypoint(pts[i], 'Punkt trasy ${i + 1}'));
    }
    if (pts.length > 1) buf.writeln(_waypoint(pts.last, 'Cel'));

    buf.writeln('  <rte>');
    buf.writeln('    <name>${_escape(route.name)}</name>');
    for (var i = 0; i < pts.length; i++) {
      final label = i == 0
          ? 'Start'
          : i == pts.length - 1
              ? 'Cel'
              : 'Punkt trasy ${i + 1}';
      buf.writeln('    <rtept lat="${pts[i].latitude}" lon="${pts[i].longitude}">');
      buf.writeln('      <name>$label</name>');
      buf.writeln('    </rtept>');
    }
    buf.writeln('  </rte>');
    buf.writeln('</gpx>');
    return buf.toString();
  }

  static String linkUri(MotorcycleRoute route) {
    final content = buildGmx(route);
    return 'data:application/gpx+xml;charset=utf-8,'
        '${Uri.encodeComponent(content)}';
  }

  static String _waypoint(LatLng p, String name) {
    return '  <wpt lat="${p.latitude}" lon="${p.longitude}">'
        '<name>$name</name></wpt>';
  }

  static List<LatLng> _decimate(List<LatLng> pts) {
    const maxPoints = 200;
    if (pts.length <= maxPoints) return pts;
    final result = <LatLng>[];
    for (var i = 0; i < maxPoints; i++) {
      final idx = (i * (pts.length - 1) / (maxPoints - 1)).round();
      result.add(pts[idx]);
    }
    result.add(pts.last);
    return result;
  }

  static String _escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

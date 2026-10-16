import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';
import '../models/point_of_interest.dart';
import '../models/road_event.dart';

/// Jeden wpis fotoradaru z wbudowanej bazy offline.
class OfflineCamera {
  final double lat;
  final double lon;

  /// 0 = stacjonarny, 1 = czerwone światło, 2 = odcinkowy pomiar.
  final int kind;
  final int? limit;
  const OfflineCamera(this.lat, this.lon, this.kind, this.limit);

  RoadEventType get type {
    switch (kind) {
      case 1:
        return RoadEventType.redLightCamera;
      case 2:
        return RoadEventType.averageSpeedCamera;
      default:
        return RoadEventType.speedCameraStationary;
    }
  }
}

/// Wbudowane bazy offline (assets/data/*.csv) — działają bez internetu,
/// natychmiast i niezależnie od Overpass (który bywa przeciążony).
class OfflineData {
  OfflineData._();
  static final OfflineData shared = OfflineData._();

  static const String _cameraAsset = 'assets/data/speed_cameras.csv';
  static const String _poiAsset = 'assets/data/motorcycle_pois.csv';

  List<OfflineCamera>? _cameras;
  List<PointOfInterest>? _pois;

  Future<List<OfflineCamera>> cameras() async {
    if (_cameras != null) return _cameras!;
    final out = <OfflineCamera>[];
    try {
      final raw = await rootBundle.loadString(_cameraAsset);
      for (final line in raw.split('\n')) {
        if (line.isEmpty) continue;
        final f = line.split(',');
        if (f.length < 3) continue;
        final lat = double.tryParse(f[0]);
        final lon = double.tryParse(f[1]);
        final kind = int.tryParse(f[2]);
        if (lat == null || lon == null || kind == null) continue;
        final limit = f.length > 3 ? int.tryParse(f[3].trim()) : null;
        out.add(OfflineCamera(lat, lon, kind, limit == 0 ? null : limit));
      }
    } catch (_) {
      // Asset niedostępny (np. testy) — zwracamy pustą listę.
    }
    _cameras = out;
    return out;
  }

  Future<List<PointOfInterest>> pois() async {
    if (_pois != null) return _pois!;
    final out = <PointOfInterest>[];
    try {
      final raw = await rootBundle.loadString(_poiAsset);
      var i = 0;
      for (final line in raw.split('\n')) {
        if (line.isEmpty) continue;
        final f = _splitCsv(line);
        if (f.length < 4) continue;
        final lat = double.tryParse(f[0]);
        final lon = double.tryParse(f[1]);
        final name = f[3].trim();
        if (lat == null || lon == null || name.isEmpty) continue;
        final category = switch (f[2].trim()) {
          'v' => POICategory.viewpoint,
          'p' => POICategory.mountainPass,
          'm' => POICategory.service,
          _ => POICategory.viewpoint,
        };
        out.add(PointOfInterest(
          id: 'poi-${i++}',
          name: name,
          coordinate: LatLng(lat, lon),
          category: category,
          description: category.label,
        ));
      }
    } catch (_) {
      // Asset niedostępny (np. testy) — zwracamy pustą listę.
    }
    _pois = out;
    return out;
  }

  /// Dzieli linię CSV respektując cudzysłowy (nazwy mogą zawierać przecinki).
  List<String> _splitCsv(String line) {
    final res = <String>[];
    final sb = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (inQuotes) {
        if (c == '"') {
          if (i + 1 < line.length && line[i + 1] == '"') {
            sb.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          sb.write(c);
        }
      } else {
        if (c == '"') {
          inQuotes = true;
        } else if (c == ',') {
          res.add(sb.toString());
          sb.clear();
        } else {
          sb.write(c);
        }
      }
    }
    res.add(sb.toString());
    return res;
  }
}

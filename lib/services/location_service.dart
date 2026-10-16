import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  static Future<LatLng?> getCurrentLocation({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final pos = await getCurrentFix(timeout: timeout);
    if (pos == null) return null;
    return LatLng(pos.latitude, pos.longitude);
  }

  /// Zwraca pełną pozycję (z dokładnością), żeby caller mógł odrzucić
  /// niepewne fixy (np. geolokalizacja WiFi/IP w przeglądarce na PC).
  static Future<Position?> getCurrentFix({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      final pos = await Geolocator.getCurrentPosition().timeout(
        timeout,
        onTimeout: () => throw TimeoutException('GPS timeout'),
      );
      return pos;
    } catch (_) {
      return null;
    }
  }
}

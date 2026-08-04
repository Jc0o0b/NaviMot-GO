import 'package:latlong2/latlong.dart';

/// Rodzaj utrudnienia ruchu na odcinku trasy.
enum TrafficSeverity {
  /// Spowolnienie / korek.
  slow,

  /// Blokada drogi (wypadek, przedmiot, awaria).
  blocked,
}

/// Odcinek trasy z utrudnieniem (korek, spowolnienie, blokada).
class TrafficSegment {
  final List<LatLng> points;
  final TrafficSeverity severity;
  final String cause;
  final String? eventId;

  const TrafficSegment({
    required this.points,
    required this.severity,
    required this.cause,
    this.eventId,
  });
}

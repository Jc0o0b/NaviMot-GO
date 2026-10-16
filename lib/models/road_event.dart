enum RoadEventType {
  police('Kontrola policyjna'),
  speedCameraStationary('Fotoradar stacjonarny'),
  speedCameraMobile('Fotoradar mobilny'),
  redLightCamera('Kamera na czerwonym świetle'),
  averageSpeedCamera('Odcinkowy pomiar prędkości'),
  accident('Wypadek'),
  obstacle('Przedmiot na drodze'),
  breakdown('Awaria pojazdu');

  final String label;
  const RoadEventType(this.label);

  /// Czy typ jest fotoradarem/kamerą (dla których podajemy limit prędkości).
  bool get isCamera =>
      this == RoadEventType.speedCameraStationary ||
      this == RoadEventType.speedCameraMobile ||
      this == RoadEventType.redLightCamera ||
      this == RoadEventType.averageSpeedCamera;

  static RoadEventType fromName(String? name) {
    // Zgodność wstecz: dawna nazwa ogólna "speedCamera".
    if (name == 'speedCamera') return RoadEventType.speedCameraStationary;
    for (final t in RoadEventType.values) {
      if (t.name == name) return t;
    }
    return RoadEventType.police;
  }
}

class RoadEvent {
  final String id;
  final RoadEventType type;
  final double lat;
  final double lon;
  final String? description;
  final DateTime createdAt;

  /// Obowiązujący limit prędkości (km/h) — głównie dla fotoradarów/kamer.
  final int? speedLimit;

  /// Identyfikator zgłaszającego (dla zdarzeń ze wspólnego backendu).
  final String? reporterId;

  /// Liczba potwierdzeń przez innych kierowców.
  final int confirmations;

  const RoadEvent({
    required this.id,
    required this.type,
    required this.lat,
    required this.lon,
    this.description,
    required this.createdAt,
    this.speedLimit,
    this.reporterId,
    this.confirmations = 0,
  });

  RoadEvent copyWith({int? confirmations}) => RoadEvent(
        id: id,
        type: type,
        lat: lat,
        lon: lon,
        description: description,
        createdAt: createdAt,
        speedLimit: speedLimit,
        reporterId: reporterId,
        confirmations: confirmations ?? this.confirmations,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'lat': lat,
        'lon': lon,
        'description': description,
        'createdAt': createdAt.millisecondsSinceEpoch,
        if (speedLimit != null) 'speedLimit': speedLimit,
        if (reporterId != null) 'reporterId': reporterId,
        if (confirmations > 0) 'confirmations': confirmations,
      };

  factory RoadEvent.fromJson(Map<String, dynamic> json) => RoadEvent(
        id: json['id'] as String? ?? '',
        type: RoadEventType.fromName(json['type'] as String?),
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
        description: json['description'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (json['createdAt'] as num?)?.toInt() ?? 0),
        speedLimit: (json['speedLimit'] as num?)?.toInt(),
        reporterId: json['reporterId'] as String?,
        confirmations: (json['confirmations'] as num?)?.toInt() ?? 0,
      );
}

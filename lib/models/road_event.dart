enum RoadEventType {
  police('Kontrola'),
  speedCamera('Fotoradar'),
  accident('Wypadek'),
  obstacle('Przedmiot na drodze'),
  breakdown('Awaria pojazdu');

  final String label;
  const RoadEventType(this.label);

  static RoadEventType fromName(String? name) {
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

  const RoadEvent({
    required this.id,
    required this.type,
    required this.lat,
    required this.lon,
    this.description,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'lat': lat,
    'lon': lon,
    'description': description,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory RoadEvent.fromJson(Map<String, dynamic> json) => RoadEvent(
    id: json['id'] as String? ?? '',
    type: RoadEventType.fromName(json['type'] as String?),
    lat: (json['lat'] as num).toDouble(),
    lon: (json['lon'] as num).toDouble(),
    description: json['description'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['createdAt'] as num?)?.toInt() ?? 0),
  );
}

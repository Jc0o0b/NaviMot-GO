class ImportantPlace {
  final String id;
  final String name;
  final String note;
  final String? photoBase64;
  final double lat;
  final double lon;
  final DateTime createdAt;

  const ImportantPlace({
    required this.id,
    required this.name,
    required this.note,
    this.photoBase64,
    required this.lat,
    required this.lon,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'note': note,
    'photoBase64': photoBase64,
    'lat': lat,
    'lon': lon,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory ImportantPlace.fromJson(Map<String, dynamic> json) =>
      ImportantPlace(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        note: json['note'] as String? ?? '',
        photoBase64: json['photoBase64'] as String?,
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (json['createdAt'] as num?)?.toInt() ?? 0),
      );
}

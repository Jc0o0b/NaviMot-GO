class HomeAddress {
  final String name;
  final double lat;
  final double lon;

  const HomeAddress({
    required this.name,
    required this.lat,
    required this.lon,
  });

  Map<String, dynamic> toJson() => {'name': name, 'lat': lat, 'lon': lon};

  factory HomeAddress.fromJson(Map<String, dynamic> json) => HomeAddress(
    name: json['name'] as String? ?? '',
    lat: (json['lat'] as num).toDouble(),
    lon: (json['lon'] as num).toDouble(),
  );
}

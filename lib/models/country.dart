import 'package:latlong2/latlong.dart';

class CountryBounds {
  final double south;
  final double north;
  final double west;
  final double east;

  const CountryBounds({
    required this.south,
    required this.north,
    required this.west,
    required this.east,
  });

  double get area => (north - south) * (east - west);

  bool contains(LatLng p) =>
      p.latitude >= south &&
      p.latitude <= north &&
      p.longitude >= west &&
      p.longitude <= east;

  CountryBounds inflated(double degrees) => CountryBounds(
        south: south - degrees,
        north: north + degrees,
        west: west - degrees,
        east: east + degrees,
      );

  LatLng get northEast => LatLng(north, east);
  LatLng get northWest => LatLng(north, west);
  LatLng get southWest => LatLng(south, west);
  LatLng get southEast => LatLng(south, east);
}

class Country {
  final String code;
  final String name;
  final CountryBounds bounds;

  const Country({
    required this.code,
    required this.name,
    required this.bounds,
  });

  bool contains(LatLng p) => bounds.contains(p);

  static const List<Country> all = [
    Country(
      code: 'PL',
      name: 'Polska',
      bounds: CountryBounds(south: 49.0, north: 54.9, west: 14.1, east: 24.2),
    ),
    Country(
      code: 'DE',
      name: 'Niemcy',
      bounds: CountryBounds(south: 47.3, north: 55.1, west: 5.9, east: 15.0),
    ),
    Country(
      code: 'CZ',
      name: 'Czechy',
      bounds: CountryBounds(south: 48.5, north: 51.1, west: 12.1, east: 18.9),
    ),
    Country(
      code: 'SK',
      name: 'Słowacja',
      bounds: CountryBounds(south: 47.7, north: 49.6, west: 16.8, east: 22.6),
    ),
    Country(
      code: 'UA',
      name: 'Ukraina',
      bounds: CountryBounds(south: 44.4, north: 52.4, west: 22.1, east: 40.2),
    ),
    Country(
      code: 'BY',
      name: 'Białoruś',
      bounds: CountryBounds(south: 51.3, north: 56.2, west: 23.2, east: 32.8),
    ),
    Country(
      code: 'LT',
      name: 'Litwa',
      bounds: CountryBounds(south: 53.9, north: 56.5, west: 20.9, east: 26.9),
    ),
    Country(
      code: 'AT',
      name: 'Austria',
      bounds: CountryBounds(south: 46.4, north: 49.0, west: 9.5, east: 17.2),
    ),
    Country(
      code: 'HU',
      name: 'Węgry',
      bounds: CountryBounds(south: 45.7, north: 48.6, west: 16.1, east: 22.9),
    ),
  ];

  static Country? byCode(String? code) {
    if (code == null) return null;
    for (final c in all) {
      if (c.code == code) return c;
    }
    return null;
  }
}

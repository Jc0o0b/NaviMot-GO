import 'package:latlong2/latlong.dart';

class PointOfInterest {
  final String id;
  final String name;
  final LatLng coordinate;
  final POICategory category;
  final String description;
  final double? rating;
  final double? distance;
  final String? wikipediaUrl;

  PointOfInterest({
    required this.id,
    required this.name,
    required this.coordinate,
    required this.category,
    required this.description,
    this.rating,
    this.distance,
    this.wikipediaUrl,
  });
}

enum POICategory {
  viewpoint('Punkt widokowy', 'binoculars'),
  mountainPass('Przełęcz górska', 'terrain'),
  scenicRoad('Malownicza droga', 'route'),
  fuel('Stacja paliw', 'local_gas_station'),
  service('Serwis motocyklowy', 'build'),
  accommodation('Nocleg', 'hotel'),
  restaurant('Restauracja', 'restaurant');

  final String label;
  final String iconName;
  const POICategory(this.label, this.iconName);
}

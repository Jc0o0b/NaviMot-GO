import 'package:flutter/material.dart';
import '../models/point_of_interest.dart';

/// Publiczna mapa kategorii POI na ikony Material (współdzielona
/// przez podgląd trasy, mapę i listę miejsc).
IconData poiIcon(POICategory category) {
  switch (category) {
    case POICategory.viewpoint:
      return Icons.visibility;
    case POICategory.mountainPass:
      return Icons.terrain;
    case POICategory.scenicRoad:
      return Icons.route;
    case POICategory.fuel:
      return Icons.local_gas_station;
    case POICategory.service:
      return Icons.build;
    case POICategory.accommodation:
      return Icons.hotel;
    case POICategory.restaurant:
      return Icons.restaurant;
  }
}

/// Kolor znacznika dla kategorii POI (używany też w podglądzie trasy,
/// żeby grupy były rozróżnialne na pierwszy rzut oka).
Color poiColor(POICategory category) {
  switch (category) {
    case POICategory.viewpoint:
      return const Color(0xFF00897B);
    case POICategory.mountainPass:
      return const Color(0xFF7B1FA2);
    case POICategory.scenicRoad:
      return const Color(0xFF00ACC1);
    case POICategory.fuel:
      return const Color(0xFF43A047);
    case POICategory.service:
      return const Color(0xFF6D4C41);
    case POICategory.accommodation:
      return const Color(0xFF3949AB);
    case POICategory.restaurant:
      return const Color(0xFFEF6C00);
  }
}

class POIMarkerWidget extends StatelessWidget {
  final PointOfInterest poi;
  const POIMarkerWidget({super.key, required this.poi});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: primary, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 2)],
      ),
      child: Icon(poiIcon(poi.category), color: primary, size: 20),
    );
  }
}

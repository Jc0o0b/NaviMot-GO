import 'package:flutter/material.dart';
import '../models/point_of_interest.dart';

class POIMarkerWidget extends StatelessWidget {
  final PointOfInterest poi;
  const POIMarkerWidget({super.key, required this.poi});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.deepOrange, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 2)],
      ),
      child: Icon(_icon(), color: Colors.deepOrange, size: 20),
    );
  }

  IconData _icon() {
    switch (poi.category) {
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
}

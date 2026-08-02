import 'package:latlong2/latlong.dart';

class RouteOptions {
  LatLng? startLocation;
  LatLng? endLocation;
  bool avoidHighways = true;
  bool preferCurvyRoads = true;
  bool includeUnpaved = false;
  double maxDistance = 500000;
  bool includeScenicDetours = true;
  bool avoidTolls = false;
  bool preferElevation = true;

  RouteOptions();
}

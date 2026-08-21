import 'package:flutter/material.dart';
import 'map_screen.dart';
import 'route_planning_screen.dart';
import 'weather_screen.dart';
import 'poi_list_screen.dart';
import 'saved_routes_screen.dart';
import 'more_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _screens = [
    const MapScreen(),
    RoutePlanningScreen(onRoutePlanned: () => setState(() => _selectedIndex = 0)),
    const WeatherScreen(),
    POIListScreen(onShowOnMap: () => setState(() => _selectedIndex = 0)),
    const SavedRoutesScreen(),
    MoreScreen(onBackToMap: () => setState(() => _selectedIndex = 0)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map), label: 'Mapa'),
          NavigationDestination(icon: Icon(Icons.route), label: 'Planuj'),
          NavigationDestination(icon: Icon(Icons.cloud), label: 'Pogoda'),
          NavigationDestination(icon: Icon(Icons.pin_drop), label: 'Miejsca'),
          NavigationDestination(icon: Icon(Icons.bookmark), label: 'Zapisane'),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Więcej'),
        ],
      ),
    );
  }
}

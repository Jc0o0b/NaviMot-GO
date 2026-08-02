import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web/web.dart' as web;
import 'providers/route_provider.dart';
import 'providers/weather_provider.dart';
import 'providers/poi_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsProvider();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider(create: (_) => RouteProvider()),
        ChangeNotifierProvider(create: (_) => WeatherProvider()),
        ChangeNotifierProvider(create: (_) => POIProvider()),
      ],
      child: const NavimotGoApp(),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) => _removeWebSplash());
  unawaited(settings.load());
}

void _removeWebSplash() {
  if (!kIsWeb) return;
  web.document.getElementById('app-splash')?.remove();
}

class NavimotGoApp extends StatelessWidget {
  const NavimotGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NaviMot GO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: Colors.deepOrange,
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

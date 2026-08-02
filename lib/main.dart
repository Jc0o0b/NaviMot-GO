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
    final base = ThemeData(
      brightness: Brightness.light,
      colorSchemeSeed: Colors.deepOrange,
      useMaterial3: true,
    );
    return MaterialApp(
      title: 'NaviMot GO',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        scaffoldBackgroundColor: const Color(0xFFF7F2EA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            color: Color(0xFF263238),
          ),
          iconTheme: IconThemeData(color: Color(0xFF263238)),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          indicatorColor: const Color(0x33FF5722),
          elevation: 8,
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          shadowColor: const Color(0x22000000),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

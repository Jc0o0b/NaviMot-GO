import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'web_utils_stub.dart' if (dart.library.js_interop) 'web_utils_web.dart';
import 'providers/route_provider.dart';
import 'providers/weather_provider.dart';
import 'providers/poi_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/events_provider.dart';
import 'providers/chat_provider.dart';
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
        ChangeNotifierProvider(create: (_) => EventsProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: const NavimotGoApp(),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) => _removeWebSplash());
  unawaited(settings.load());
}

void _removeWebSplash() {
  if (!kIsWeb) return;
  removeWebSplash();
}

class NavimotGoApp extends StatelessWidget {
  const NavimotGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        final hc = settings.highContrast;
        final accent = settings.accentColor;
        return MaterialApp(
          title: 'NaviMot GO',
          debugShowCheckedModeBanner: false,
          theme: hc
              ? _highContrastTheme(Brightness.light, accent)
              : _lightTheme(accent),
          darkTheme: hc
              ? _highContrastTheme(Brightness.dark, accent)
              : _darkTheme(accent),
          themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
          home: const SplashScreen(),
        );
      },
    );
  }

  ThemeData _lightTheme(Color accent) {
    final base = ThemeData(
      brightness: Brightness.light,
      colorSchemeSeed: accent,
      useMaterial3: true,
      fontFamily: 'Montserrat',
    );
    return base.copyWith(
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
        indicatorColor: accent.withValues(alpha: 0.2),
        elevation: 8,
        height: 60,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
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
    );
  }

  ThemeData _darkTheme(Color accent) {
    final base = ThemeData(
      brightness: Brightness.dark,
      colorSchemeSeed: accent,
      useMaterial3: true,
      fontFamily: 'Montserrat',
    );
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF131518),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          color: Colors.white,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF1D2023),
        surfaceTintColor: Colors.transparent,
        indicatorColor: accent.withValues(alpha: 0.33),
        elevation: 8,
        height: 60,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF23262A),
        elevation: 1,
        shadowColor: const Color(0x66000000),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  /// Motyw wysokiego kontrastu („Tryb słońca”) — czytelny w pełnym słońcu.
  ThemeData _highContrastTheme(Brightness brightness, Color accent) {
    final isLight = brightness == Brightness.light;
    final bg = isLight ? Colors.white : Colors.black;
    final surface = isLight ? Colors.white : const Color(0xFF0E0E0E);
    final onSurface = isLight ? Colors.black : Colors.white;
    final border = isLight ? Colors.black : Colors.white;

    final base = ThemeData(
      brightness: brightness,
      colorSchemeSeed: accent,
      useMaterial3: true,
      fontFamily: 'Montserrat',
    );
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        surface: surface,
        onSurface: onSurface,
        outline: border,
      ),
      scaffoldBackgroundColor: bg,
      textTheme: base.textTheme.apply(
        bodyColor: onSurface,
        displayColor: onSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
          color: onSurface,
        ),
        iconTheme: IconThemeData(color: onSurface),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: accent.withValues(alpha: 0.33),
        elevation: 8,
        height: 64,
        labelTextStyle: WidgetStateProperty.all(
          TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800, color: onSurface),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

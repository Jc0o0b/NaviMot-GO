import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/app_logo.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  late final Animation<double> _wordFade;
  late final Animation<double> _wordOffset;
  late final Animation<double> _road;
  late final Animation<double> _swoosh;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _scale = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
    );
    _opacity = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
    );
    _wordFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.35, 0.6, curve: Curves.easeOut),
    );
    _wordOffset = Tween<double>(begin: 24, end: 0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.35, 0.6, curve: Curves.easeOutCubic),
      ),
    );
    _road = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.15, 0.7, curve: Curves.easeOut),
    );
    _swoosh = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.55, 0.95, curve: Curves.easeOut),
    );
    _ctrl.forward();
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) _finish();
    });
  }

  Future<void> _finish() async {
    final settings = context.read<SettingsProvider>();
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (!settings.isLoaded && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              scheme.primaryContainer.withValues(alpha: 0.45),
            ],
          ),
        ),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: _scale.value,
                    child: Opacity(
                      opacity: _opacity.value,
                      child: SizedBox(
                        width: 150,
                        height: 150,
                        child: AppLogo(swoosh: _swoosh.value),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Opacity(
                    opacity: _wordFade.value,
                    child: Transform.translate(
                      offset: Offset(0, _wordOffset.value),
                      child: const NaviMotGoWordmark(size: 30),
                    ),
                  ),
                  const SizedBox(height: 22),
                  ClipRect(
                    child: Align(
                      alignment: Alignment.center,
                      child: FractionallySizedBox(
                        widthFactor: _road.value,
                        child: const SizedBox(
                          width: 220,
                          height: 8,
                          child: CustomPaint(painter: _DashedRoadPainter()),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DashedRoadPainter extends CustomPainter {
  const _DashedRoadPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF5722).withValues(alpha: 0.6)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const dash = 16.0;
    const gap = 12.0;
    var x = 6.0;
    while (x < size.width - 4) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(x + dash, size.height / 2),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double swoosh;

  const AppLogo({super.key, this.swoosh = 1.0});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _AppLogoPainter(swoosh: swoosh));
  }
}

class NaviMotGoWordmark extends StatelessWidget {
  final double size;

  const NaviMotGoWordmark({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'NaviMot',
          style: TextStyle(
            color: const Color(0xFF263238),
            fontSize: size,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFFF5722),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'GO',
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.72,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }
}

class _AppLogoPainter extends CustomPainter {
  final double swoosh;

  static const _dark = Color(0xFF263238);
  static const _darkMetal = Color(0xFF455A64);
  static const _orange = Color(0xFFFF5722);

  _AppLogoPainter({required this.swoosh});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 100;
    canvas.save();
    canvas.scale(s, s);

    final shadow = Paint()..color = const Color(0x33808080);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 88), width: 76, height: 6),
      shadow,
    );

    final swooshPaint = Paint()
      ..color = _orange.withValues(alpha: 0.55 * swoosh)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    if (swoosh > 0) {
      for (final (y, len) in [(46.0, 18.0), (56.0, 26.0), (66.0, 18.0)]) {
        canvas.drawLine(
          Offset(6, y),
          Offset(6 + len * swoosh, y),
          swooshPaint,
        );
      }
    }

    _wheel(canvas, const Offset(22, 76), 14);
    _wheel(canvas, const Offset(78, 76), 14);

    final stroke = Paint()
      ..color = _dark
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // rear fender
    canvas.drawPath(
      Path()
        ..moveTo(6, 72)
        ..quadraticBezierTo(22, 56, 38, 72),
      Paint()
        ..color = _dark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // seat
    canvas.drawPath(
      Path()
        ..moveTo(16, 44)
        ..lineTo(40, 44)
        ..lineTo(40, 38)
        ..quadraticBezierTo(28, 33, 16, 37)
        ..close(),
      Paint()..color = _dark,
    );

    // fuel tank
    canvas.drawPath(
      Path()
        ..moveTo(42, 52)
        ..lineTo(58, 52)
        ..lineTo(63, 42)
        ..lineTo(55, 28)
        ..quadraticBezierTo(46, 24, 40, 30)
        ..quadraticBezierTo(38, 40, 42, 52)
        ..close(),
      Paint()..color = _orange,
    );

    // frame spine
    canvas.drawPath(
      Path()
        ..moveTo(63, 44)
        ..lineTo(50, 56)
        ..lineTo(24, 76),
      stroke..strokeWidth = 5,
    );

    // engine
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(38, 56, 16, 12),
        const Radius.circular(3),
      ),
      Paint()..color = _darkMetal,
    );
    canvas.drawRect(const Rect.fromLTWH(40, 58, 12, 3), Paint()..color = _orange);

    // exhaust + muffler
    canvas.drawPath(
      Path()
        ..moveTo(50, 68)
        ..lineTo(28, 80),
      Paint()
        ..color = _dark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(18, 78, 15, 7),
        const Radius.circular(3),
      ),
      Paint()..color = _darkMetal,
    );
    canvas.drawRect(const Rect.fromLTWH(31, 79, 2, 5), Paint()..color = _orange);

    // front fork
    canvas.drawPath(
      Path()
        ..moveTo(64, 34)
        ..lineTo(70, 52)
        ..lineTo(78, 76),
      Paint()
        ..color = _dark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // handlebar + grip
    canvas.drawPath(
      Path()
        ..moveTo(58, 27)
        ..lineTo(72, 31),
      Paint()
        ..color = _dark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(const Offset(72, 31), 2.6, Paint()..color = _orange);

    // headlight
    canvas.drawCircle(const Offset(70, 42), 3, Paint()..color = _orange);

    // front fender
    canvas.drawPath(
      Path()
        ..moveTo(66, 70)
        ..quadraticBezierTo(78, 58, 92, 70),
      Paint()
        ..color = _dark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    canvas.restore();
  }

  void _wheel(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF37474F));
    canvas.drawCircle(c, r - 4, Paint()..color = _dark);
    canvas.drawCircle(c, r - 6.5, Paint()..color = const Color(0xFFECEFF1));
    canvas.drawCircle(c, 2, Paint()..color = _orange);
  }

  @override
  bool shouldRepaint(covariant _AppLogoPainter oldDelegate) =>
      oldDelegate.swoosh != swoosh;
}

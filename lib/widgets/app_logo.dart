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

  _AppLogoPainter({required this.swoosh});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 100;
    canvas.save();
    canvas.scale(s, s);

    final frame = Paint()
      ..color = const Color(0xFF263238)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final orange = Paint()..color = const Color(0xFFFF5722);
    final darkMetal = Paint()..color = const Color(0xFF455A64);

    final shadow = Paint()..color = const Color(0x33808080);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 84), width: 76, height: 7),
      shadow,
    );

    final swooshPaint = Paint()
      ..color = const Color(0xFFFF5722).withValues(alpha: 0.55 * swoosh)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    if (swoosh > 0) {
      for (final (y, len) in [(46.0, 24.0), (56.0, 32.0), (66.0, 24.0)]) {
        canvas.drawLine(
          Offset(6, y),
          Offset(6 + len * swoosh, y),
          swooshPaint,
        );
      }
    }

    _wheel(canvas, const Offset(26, 74), 14);
    _wheel(canvas, const Offset(74, 74), 14);

    final body = Path()
      ..moveTo(26, 74)
      ..lineTo(33, 50)
      ..lineTo(45, 48)
      ..lineTo(58, 42)
      ..lineTo(63, 48)
      ..lineTo(74, 74);
    canvas.drawPath(body, frame);

    final bar = Path()
      ..moveTo(58, 42)
      ..lineTo(68, 38)
      ..lineTo(72, 41);
    canvas.drawPath(bar, frame);
    canvas.drawCircle(const Offset(72, 41), 2.5, orange);

    canvas.drawCircle(const Offset(69, 50), 3, orange);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(34, 56, 16, 11),
        const Radius.circular(3),
      ),
      orange,
    );
    canvas.drawLine(const Offset(34, 60), const Offset(18, 66), darkMetal);
    canvas.drawCircle(const Offset(17, 67), 3, darkMetal);

    canvas.restore();
  }

  void _wheel(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF37474F));
    canvas.drawCircle(c, r - 4, Paint()..color = const Color(0xFF263238));
    canvas.drawCircle(c, r - 6.5, Paint()..color = const Color(0xFFECEFF1));
    canvas.drawCircle(c, 2, Paint()..color = const Color(0xFFFF5722));
  }

  @override
  bool shouldRepaint(covariant _AppLogoPainter oldDelegate) =>
      oldDelegate.swoosh != swoosh;
}

import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  const SectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.actions,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final w = MediaQuery.sizeOf(context).width;
    final titleSize = w < 360 ? 18.0 : 22.0;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(8, topPad + 12, 8, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF7043), Color(0xFFFF5722)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
              color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: onBack != null
                  ? IconButton(
                      onPressed: onBack,
                      tooltip: 'Wróć',
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 26),
                    )
                  : null,
            ),
            Expanded(
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: titleSize,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 48,
              child: actions != null
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.max,
                      children: actions!,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

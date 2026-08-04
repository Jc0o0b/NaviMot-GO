import 'package:flutter/material.dart';
import '../models/traffic_info.dart';

Color trafficSegmentColor(TrafficSeverity severity) =>
    severity == TrafficSeverity.blocked
        ? Colors.red
        : const Color(0xFFFFA000);

/// Legenda odcinków z utrudnieniami ruchu.
class TrafficLegend extends StatelessWidget {
  final bool hasSlow;
  final bool hasBlock;
  const TrafficLegend({
    super.key,
    required this.hasSlow,
    required this.hasBlock,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasSlow && !hasBlock) return const SizedBox.shrink();
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        if (hasSlow)
          const _LegendDot(
            color: Color(0xFFFFA000),
            label: 'Korek / spowolnienie',
          ),
        if (hasBlock)
          const _LegendDot(color: Colors.red, label: 'Blokada drogi'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

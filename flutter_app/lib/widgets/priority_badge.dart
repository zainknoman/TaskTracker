import 'package:flutter/material.dart';

import 'app_badge.dart';

/// Web `.badge-low|medium|high|critical`.
class PriorityBadge extends StatelessWidget {
  final String priority;
  const PriorityBadge({super.key, required this.priority});

  (Color, Color) _colors() {
    switch (priority) {
      case 'critical':
        return (const Color(0xFFFEE2E2), const Color(0xFF991B1B));
      case 'high':
        return (const Color(0xFFFEF3C7), const Color(0xFF92400E));
      case 'medium':
        return (const Color(0xFFDBEAFE), const Color(0xFF1D4ED8));
      default: // low
        return (const Color(0xFFD1FAE5), const Color(0xFF065F46));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors();
    final label = priority.isEmpty
        ? priority
        : priority[0].toUpperCase() + priority.substring(1);
    return AppBadge(label: label, background: c.$1, foreground: c.$2);
  }
}

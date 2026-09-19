import 'package:flutter/material.dart';

import '../core/tokens.dart';
import 'app_badge.dart';

/// Task / project / milestone / sprint status, colored like the web `.badge-*` classes.
class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  (Color, Color) _colors() {
    switch (status) {
      case 'inprogress':
        return (Brand.primaryLight, Brand.primary);
      case 'completed':
        return (Brand.successLight, Brand.success);
      case 'blocked':
        return (Brand.dangerLight, Brand.danger);
      case 'planning':
        return (const Color(0xFFEDE9FE), const Color(0xFF7C3AED));
      case 'active':
        return (const Color(0xFFD1FAE5), const Color(0xFF065F46));
      case 'onhold':
      case 'on-hold':
        return (const Color(0xFFFEF3C7), const Color(0xFF92400E));
      case 'archived':
        return (const Color(0xFFF1F5F9), const Color(0xFF64748B));
      default: // pending
        return (Brand.warningLight, Brand.warning);
    }
  }

  String _label() {
    switch (status) {
      case 'inprogress':
        return 'In Progress';
      case 'onhold':
      case 'on-hold':
        return 'On Hold';
      default:
        if (status.isEmpty) return status;
        final s = status.replaceAll('_', ' ');
        return s[0].toUpperCase() + s.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors();
    return AppBadge(label: _label(), background: c.$1, foreground: c.$2);
  }
}

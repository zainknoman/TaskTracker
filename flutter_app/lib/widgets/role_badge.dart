import 'package:flutter/material.dart';

import '../core/tokens.dart';
import 'app_badge.dart';

class RoleBadge extends StatelessWidget {
  final String role;
  const RoleBadge({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, fg) = switch (role) {
      'owner' => (const Color(0xFFFEF3C7), const Color(0xFF92400E)),
      'member' => (Brand.primaryLight, Brand.primary),
      _ => (c.surface2, c.text3),
    };
    final label = role.isEmpty
        ? role
        : role[0].toUpperCase() + role.substring(1);
    return AppBadge(
      label: label,
      background: bg,
      foreground: fg,
      border: role == 'guest' ? Border.all(color: c.border) : null,
    );
  }
}

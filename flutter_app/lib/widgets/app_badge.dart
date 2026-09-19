import 'package:flutter/material.dart';

import '../core/tokens.dart';

/// Web `.badge`: pill, 2px/8px padding, .7rem, weight 600.
class AppBadge extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final Border? border;

  const AppBadge({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: Radii.pillAll,
        border: border,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: rem(0.7),
          fontWeight: FontWeight.w600,
          color: foreground,
          height: 1.6,
        ),
      ),
    );
  }
}

/// Web `.project-card-code`, `.milestone-task-count`: neutral outlined pill.
class OutlineChip extends StatelessWidget {
  final String label;
  const OutlineChip(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: Radii.pillAll,
        border: Border.all(color: c.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: rem(0.72),
          fontWeight: FontWeight.w600,
          color: c.text3,
        ),
      ),
    );
  }
}

/// Web `.tag-color-N` chips (task tags, member skills).
class TagChip extends StatelessWidget {
  final String label;
  final int index;
  const TagChip(this.label, {super.key, this.index = 0});

  static const _palette = [
    (Color(0xFFDBEAFE), Color(0xFF1D4ED8)),
    (Color(0xFFD1FAE5), Color(0xFF065F46)),
    (Color(0xFFFEF3C7), Color(0xFF92400E)),
    (Color(0xFFFEE2E2), Color(0xFF991B1B)),
    (Color(0xFFEDE9FE), Color(0xFF6D28D9)),
    (Color(0xFFFCE7F3), Color(0xFF9D174D)),
    (Color(0xFFCCFBF1), Color(0xFF0F766E)),
    (Color(0xFFFFF7ED), Color(0xFF9A3412)),
  ];

  @override
  Widget build(BuildContext context) {
    final p = _palette[index % _palette.length];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: p.$1, borderRadius: Radii.pillAll),
      child: Text(
        label,
        style: TextStyle(
          fontSize: rem(0.68),
          fontWeight: FontWeight.w600,
          color: p.$2,
        ),
      ),
    );
  }
}

/// Web `.project-pill`: bordered pill tinted with the project color.
class ProjectPill extends StatelessWidget {
  final String name;
  final Color color;
  const ProjectPill({super.key, required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: Radii.pillAll,
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: rem(0.7),
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

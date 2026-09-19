import 'package:flutter/material.dart';

import '../core/tokens.dart';

/// Web `.card`: surface, 1px border, 16px radius, `--shadow`.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final BorderRadius? radius;
  final List<BoxShadow>? shadow;
  final Color? color;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.radius,
    this.shadow,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final r = radius ?? Radii.lgAll;
    return Container(
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: r,
        border: Border.all(color: c.border),
        boxShadow: shadow ?? c.shadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: r,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: padding == null
              ? child
              : Padding(padding: padding!, child: child),
        ),
      ),
    );
  }
}

/// Web `.card-header`: title on the left, optional trailing widget, bottom border.
class CardHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const CardHeader(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A `.card` with a `.card-header` and body.
class SectionCard extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget child;
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardHeader(title, trailing: trailing),
          child,
        ],
      ),
    );
  }
}

/// Web `.no-data` line.
class NoData extends StatelessWidget {
  final String message;
  const NoData(this.message, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Center(
      child: Text(
        message,
        style: TextStyle(fontSize: rem(0.85), color: context.c.text3),
      ),
    ),
  );
}

/// Web `.mini-task-item` row: leading, expanding middle, trailing; divider between rows.
class MiniRow extends StatelessWidget {
  final Widget leading;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool last;
  const MiniRow({
    super.key,
    required this.leading,
    required this.child,
    this.trailing,
    this.onTap,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: c.border)),
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 10),
            Expanded(child: child),
            if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          ],
        ),
      ),
    );
  }
}

/// A small filled dot (`.mini-task-dot`, `.nav-project-dot`, ...).
class ColorDot extends StatelessWidget {
  final Color color;
  final double size;
  const ColorDot(this.color, {super.key, this.size = 8});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// Web `.progress-track` / `.project-progress-track` / `.mini-progress-track`.
class AppProgress extends StatelessWidget {
  final double value; // 0..1
  final double height;
  final Color? color;
  final bool gradient; // `.progress-fill` uses primary → #60a5fa

  const AppProgress({
    super.key,
    required this.value,
    this.height = 8,
    this.color,
    this.gradient = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fill = color ?? Brand.primary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: height,
        color: c.border,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: gradient ? null : fill,
              gradient: gradient
                  ? const LinearGradient(
                      colors: [Brand.primary, Color(0xFF60A5FA)],
                    )
                  : null,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
    );
  }
}

/// Web `.stat-card`: 3px colored top bar, uppercase label, big number, faded icon.
class StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final String emoji;
  final VoidCallback? onTap;
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.emoji,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AppCard(
      onTap: onTap,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(height: 3, color: color),
          ),
          Positioned(
            right: 14,
            top: 0,
            bottom: 0,
            child: Center(
              child: Opacity(
                opacity: .1,
                child: Text(
                  emoji,
                  style: TextStyle(fontSize: rem(2.2), height: 1),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: rem(0.72),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.05 * rem(0.72),
                    color: c.text3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: rem(1.9),
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../core/tokens.dart';

/// The web logo: blue rounded square with three white bars (index.html `.brand-icon`).
class BrandLogo extends StatelessWidget {
  final double size;
  const BrandLogo({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _LogoPainter());
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 28;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(8 * s)),
      Paint()..color = Brand.primary,
    );
    final line = Paint()
      ..color = Colors.white
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(7 * s, 9 * s), Offset(21 * s, 9 * s), line);
    canvas.drawLine(Offset(7 * s, 14 * s), Offset(16 * s, 14 * s), line);
    canvas.drawLine(Offset(7 * s, 19 * s), Offset(18 * s, 19 * s), line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Web `.topbar`: 60px, surface, bottom border. Shows the breadcrumb (`.topbar-breadcrumb`)
/// and right-side actions. Leading is the hamburger (opens the drawer) or a back button.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final List<String> crumbs;
  final bool showBack;
  final List<Widget> actions;

  const AppTopBar({
    super.key,
    required this.crumbs,
    this.showBack = false,
    this.actions = const [],
  });

  @override
  Size get preferredSize => const Size.fromHeight(61);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 60,
      backgroundColor: c.surface,
      leadingWidth: 52,
      titleSpacing: 0,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: showBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back, size: 19),
                onPressed: () => Navigator.maybePop(context),
                style: IconButton.styleFrom(foregroundColor: c.text2),
              )
            : Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu, size: 19),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                  style: IconButton.styleFrom(foregroundColor: c.text2),
                ),
              ),
      ),
      title: _Breadcrumb(crumbs: crumbs),
      actions: [...actions, const SizedBox(width: 12)],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: c.border),
      ),
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  final List<String> crumbs;
  const _Breadcrumb({required this.crumbs});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final style = TextStyle(fontSize: rem(0.82), color: c.text3);
    final children = <Widget>[];
    for (var i = 0; i < crumbs.length; i++) {
      final last = i == crumbs.length - 1;
      if (i > 0) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text('›', style: style.copyWith(color: c.border2)),
          ),
        );
      }
      children.add(
        Flexible(
          flex: last ? 3 : 1,
          child: Text(
            crumbs[i],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: last
                ? style.copyWith(color: c.text, fontWeight: FontWeight.w600)
                : style,
          ),
        ),
      );
    }
    return Row(children: children);
  }
}

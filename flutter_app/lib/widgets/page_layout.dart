import 'package:flutter/material.dart';

import '../core/tokens.dart';
import 'app_top_bar.dart';

/// Web `.content-area` padding: 22px, 12px on narrow screens (<600px).
EdgeInsets pagePadding(BuildContext context) =>
    EdgeInsets.all(MediaQuery.sizeOf(context).width <= 600 ? 12 : 22);

/// Scaffold with the web topbar + back button, for screens pushed on top of the shell
/// (detail pages, Calendar, Gantt, Analytics, Team, Members).
class SubPage extends StatelessWidget {
  final List<String> crumbs;
  final List<Widget> actions;
  final Widget body;
  const SubPage({
    super.key,
    required this.crumbs,
    required this.body,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.c.bg,
      appBar: AppTopBar(crumbs: crumbs, showBack: true, actions: actions),
      body: body,
    );
  }
}

/// Lays children out in `columns` equal columns with a gap (web `display:grid` on mobile).
class GridWrap extends StatelessWidget {
  final int columns;
  final double gap;
  final List<Widget> children;
  const GridWrap({
    super.key,
    required this.children,
    this.columns = 2,
    this.gap = 10,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final width = (box.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final c in children) SizedBox(width: width, child: c),
          ],
        );
      },
    );
  }
}

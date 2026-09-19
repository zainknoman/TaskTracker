import 'package:flutter/material.dart';

import '../core/tokens.dart';

/// Web `.view-header`: title + subtitle on the left, actions on the right (wraps on mobile).
class ViewHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  const ViewHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle!,
                    style: TextStyle(fontSize: rem(0.82), color: c.text3),
                  ),
                ),
            ],
          ),
          if (actions.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actions,
            ),
        ],
      ),
    );
  }
}

/// Web `.filter-bar`: surface strip with compact selects.
class FilterBar extends StatelessWidget {
  final List<Widget> children;
  const FilterBar({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: Radii.mdAll,
        border: Border.all(color: c.border),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      ),
    );
  }
}

/// Web `.filter-select`: compact select on `--bg` with border.
class FilterSelect<T> extends StatelessWidget {
  final T? value;
  final String allLabel;
  final List<(T, String)> options;
  final ValueChanged<T?> onChanged;
  const FilterSelect({
    super.key,
    required this.value,
    required this.allLabel,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      constraints: const BoxConstraints(minHeight: 32),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: Radii.smAll,
        border: Border.all(color: c.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T?>(
          value: value,
          isDense: true,
          icon: Icon(Icons.expand_more, size: 16, color: c.text3),
          dropdownColor: c.surface,
          borderRadius: Radii.mdAll,
          style: TextStyle(fontSize: rem(0.8), color: c.text),
          items: [
            DropdownMenuItem<T?>(value: null, child: Text(allLabel)),
            for (final o in options)
              DropdownMenuItem<T?>(value: o.$1, child: Text(o.$2)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Web `.view-toggle-group`: joined icon toggle buttons.
class ViewToggle extends StatelessWidget {
  final int index;
  final List<IconData> icons;
  final ValueChanged<int> onChanged;
  const ViewToggle({
    super.key,
    required this.index,
    required this.icons,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: c.border),
        borderRadius: Radii.smAll,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < icons.length; i++)
            InkWell(
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                color: i == index ? Brand.primary : c.surface,
                child: Icon(
                  icons[i],
                  size: 14,
                  color: i == index ? Colors.white : c.text3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Web `.project-tabs`: underline tabs on a 2px rail; the active tab is primary-colored.
class UnderlineTabs extends StatelessWidget {
  final List<String> tabs;
  final int index;
  final ValueChanged<int> onChanged;
  const UnderlineTabs({
    super.key,
    required this.tabs,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border, width: 2)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (i, t) in tabs.indexed)
              InkWell(
                onTap: () => onChanged(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  margin: const EdgeInsets.only(bottom: -2),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: i == index ? Brand.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    t,
                    style: TextStyle(
                      fontSize: rem(0.85),
                      fontWeight: FontWeight.w600,
                      color: i == index ? Brand.primary : c.text3,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

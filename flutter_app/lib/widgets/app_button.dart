import 'package:flutter/material.dart';

import '../core/tokens.dart';

/// Web `.btn` variants: primary, secondary, ghost, danger, success.
enum AppButtonVariant { primary, secondary, ghost, danger, success }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool small; // .btn-sm
  final bool loading;
  final bool expand; // .login-btn (full width, centered)

  const AppButton(
    this.label, {
    super.key,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.small = false,
    this.loading = false,
    this.expand = false,
  });

  const AppButton.secondary(
    this.label, {
    super.key,
    this.onPressed,
    this.icon,
    this.small = false,
    this.loading = false,
    this.expand = false,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.ghost(
    this.label, {
    super.key,
    this.onPressed,
    this.icon,
    this.small = false,
    this.loading = false,
    this.expand = false,
  }) : variant = AppButtonVariant.ghost;

  const AppButton.danger(
    this.label, {
    super.key,
    this.onPressed,
    this.icon,
    this.small = false,
    this.loading = false,
    this.expand = false,
  }) : variant = AppButtonVariant.danger;

  @override
  Widget build(BuildContext context) {
    final fontSize = small ? rem(0.78) : rem(0.85);
    final padding = small
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 5)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 9);

    final fg = switch (variant) {
      AppButtonVariant.primary ||
      AppButtonVariant.danger ||
      AppButtonVariant.success => Colors.white,
      _ => null,
    };

    final child = loading
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: fg ?? Brand.primary,
            ),
          )
        : Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15),
                const SizedBox(width: 5),
              ],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    final textStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
    );
    final effective = loading ? null : onPressed;

    Widget button;
    switch (variant) {
      case AppButtonVariant.primary:
        button = FilledButton(
          onPressed: effective,
          style: FilledButton.styleFrom(
            padding: padding,
            textStyle: textStyle,
            minimumSize: Size(0, small ? 28 : 36),
          ),
          child: child,
        );
      case AppButtonVariant.danger:
        button = FilledButton(
          onPressed: effective,
          style: FilledButton.styleFrom(
            backgroundColor: Brand.danger,
            padding: padding,
            textStyle: textStyle,
            minimumSize: Size(0, small ? 28 : 36),
          ),
          child: child,
        );
      case AppButtonVariant.success:
        button = FilledButton(
          onPressed: effective,
          style: FilledButton.styleFrom(
            backgroundColor: Brand.success,
            padding: padding,
            textStyle: textStyle,
            minimumSize: Size(0, small ? 28 : 36),
          ),
          child: child,
        );
      case AppButtonVariant.secondary:
        button = OutlinedButton(
          onPressed: effective,
          style: OutlinedButton.styleFrom(
            padding: padding,
            textStyle: textStyle,
            minimumSize: Size(0, small ? 28 : 36),
          ),
          child: child,
        );
      case AppButtonVariant.ghost:
        button = TextButton(
          onPressed: effective,
          style: TextButton.styleFrom(
            padding: padding,
            textStyle: textStyle,
            minimumSize: Size(0, small ? 28 : 36),
          ),
          child: child,
        );
    }
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Web `.topbar-icon-btn` / `.action-btn`: square ghost icon button.
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final Color? color;
  final bool danger;

  const AppIconButton(
    this.icon, {
    super.key,
    this.onPressed,
    this.tooltip,
    this.size = 18,
    this.color,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: size),
      style: IconButton.styleFrom(
        foregroundColor: color ?? (danger ? Brand.danger : c.text2),
        minimumSize: const Size(34, 34),
        fixedSize: const Size(34, 34),
      ),
    );
  }
}

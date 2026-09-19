import 'package:flutter/material.dart';

import '../core/tokens.dart';

enum _ToastType { success, error, warning, info }

/// Web `.toast`: surface card, colored leading icon, message, × close.
class AppToast {
  static void error(BuildContext context, String message) =>
      _show(context, message, _ToastType.error);
  static void success(BuildContext context, String message) =>
      _show(context, message, _ToastType.success);
  static void warning(BuildContext context, String message) =>
      _show(context, message, _ToastType.warning);
  static void info(BuildContext context, String message) =>
      _show(context, message, _ToastType.info);

  static void _show(BuildContext context, String message, _ToastType type) {
    final c = context.c;
    final messenger = ScaffoldMessenger.of(context);
    final (icon, color) = switch (type) {
      _ToastType.success => (Icons.check_circle, Brand.success),
      _ToastType.error => (Icons.cancel, Brand.danger),
      _ToastType.warning => (Icons.warning_rounded, Brand.warning),
      _ToastType.info => (Icons.info, Brand.primary),
    };
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(milliseconds: 3500),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 22),
        padding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: Radii.mdAll,
            border: Border.all(color: c.border),
            boxShadow: c.shadowLg,
          ),
          child: Row(
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(fontSize: rem(0.85), color: c.text),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: messenger.hideCurrentSnackBar,
                child: Icon(Icons.close, size: 16, color: c.text3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

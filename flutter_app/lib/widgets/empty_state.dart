import 'package:flutter/material.dart';

import '../core/tokens.dart';

/// Web `.empty-state`: faded icon, h3 title, hint paragraph, optional action.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? hint;
  final Widget? action;
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.hint,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 56),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: c.text3.withValues(alpha: .5)),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: rem(1),
                fontWeight: FontWeight.w600,
                color: c.text2,
              ),
            ),
            if (hint != null) ...[
              const SizedBox(height: 5),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: rem(0.82), color: c.text3),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

/// Centered spinner used while a view loads.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(strokeWidth: 3));
}

/// Inline error, styled like the web `.login-error` block.
class ErrorView extends StatelessWidget {
  final Object error;
  const ErrorView(this.error, {super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: Brand.dangerLight,
            borderRadius: Radii.smAll,
            border: Border.all(color: const Color(0xFFFCA5A5)),
          ),
          child: Text(
            'Error: $error',
            style: TextStyle(
              fontSize: rem(0.82),
              fontWeight: FontWeight.w500,
              color: Brand.danger,
            ),
          ),
        ),
      ),
    );
  }
}

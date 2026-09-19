import 'package:flutter/material.dart';

import '../core/tokens.dart';
import 'app_button.dart';

/// Web `.form-group label`: uppercase, .72rem, bold, text-2 (+ red `*` when required).
class FormLabel extends StatelessWidget {
  final String text;
  final bool required;
  const FormLabel(this.text, {super.key, this.required = false});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text.rich(
        TextSpan(
          text: text.toUpperCase(),
          style: TextStyle(
            fontSize: rem(0.72),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.03 * rem(0.72),
            color: c.text2,
          ),
          children: [
            if (required)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: Brand.danger),
              ),
          ],
        ),
      ),
    );
  }
}

/// Labelled text input matching web `.form-group input` / `.login-field input`.
class AppTextField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final String? hint;
  final bool required;
  final bool obscure;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final Widget? prefixIcon;
  final bool autofocus;

  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.required = false,
    this.obscure = false,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.prefixIcon,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) FormLabel(label, required: required),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          maxLines: obscure ? 1 : maxLines,
          minLines: maxLines > 1 ? 3 : null,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          autofocus: autofocus,
          style: TextStyle(fontSize: rem(0.85), color: context.c.text),
          decoration: InputDecoration(hintText: hint, prefixIcon: prefixIcon),
        ),
      ],
    );
  }
}

/// Labelled select matching web `.form-group select`.
class AppDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool required;
  final String? Function(T?)? validator;

  const AppDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.required = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) FormLabel(label, required: required),
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          validator: validator,
          isExpanded: true,
          icon: Icon(Icons.expand_more, size: 18, color: c.text3),
          dropdownColor: c.surface,
          borderRadius: Radii.mdAll,
          style: TextStyle(fontSize: rem(0.85), color: c.text),
          decoration: const InputDecoration(),
        ),
      ],
    );
  }
}

/// Bottom-sheet form chrome mirroring the web `.modal`: title + close, scrollable body,
/// right-aligned footer actions separated by borders.
class SheetScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget> footer;
  const SheetScaffold({
    super.key,
    required this.title,
    required this.body,
    this.footer = const [],
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final mq = MediaQuery.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: mq.size.height * 0.92),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 14, 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: c.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    _CloseButton(onTap: () => Navigator.maybePop(context)),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  child: body,
                ),
              ),
              if (footer.isNotEmpty)
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: c.border)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (var i = 0; i < footer.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        footer[i],
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Web `.modal-close`: 28px square, turns red on hover/press.
class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: Radii.smAll,
      hoverColor: Brand.dangerLight,
      highlightColor: Brand.dangerLight,
      child: SizedBox(
        width: 28,
        height: 28,
        child: Icon(Icons.close, size: 14, color: context.c.text3),
      ),
    );
  }
}

/// Web `.modal-footer` button pair (Cancel + primary).
List<Widget> sheetActions(
  BuildContext context, {
  required String submitLabel,
  required VoidCallback? onSubmit,
  bool loading = false,
}) {
  return [
    AppButton.secondary('Cancel', onPressed: () => Navigator.maybePop(context)),
    AppButton(submitLabel, onPressed: onSubmit, loading: loading),
  ];
}

/// Web-style `.confirm-dialog`. Returns true if confirmed.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
}) async {
  final c = context.c;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: c.surface,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(
        borderRadius: Radii.lgAll,
        side: BorderSide(color: c.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 26, 26, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: Brand.warningLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  size: 22,
                  color: Brand.warning,
                ),
              ),
              const SizedBox(height: 14),
              Text(title, style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: rem(0.85),
                  color: c.text2,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppButton.secondary(
                    'Cancel',
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                  const SizedBox(width: 8),
                  AppButton.danger(
                    confirmLabel,
                    onPressed: () => Navigator.pop(ctx, true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return result ?? false;
}

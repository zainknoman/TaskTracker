import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens.dart';
import '../../data/exceptions.dart';
import '../../providers/workspace_providers.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_form.dart';
import '../../widgets/app_toast.dart';

class WorkspaceSwitcherSheet extends ConsumerWidget {
  const WorkspaceSwitcherSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const WorkspaceSwitcherSheet(),
    );
  }

  Future<void> _createWorkspace(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SheetScaffold(
        title: 'New Workspace',
        footer: [
          AppButton.secondary(
            'Cancel',
            onPressed: () => Navigator.pop(sheetContext),
          ),
          AppButton(
            'Create',
            onPressed: () =>
                Navigator.pop(sheetContext, controller.text.trim()),
          ),
        ],
        body: AppTextField(
          label: 'Workspace Name',
          controller: controller,
          autofocus: true,
        ),
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      final workspace = await ref
          .read(workspaceRepositoryProvider)
          .create(name);
      ref.invalidate(workspaceListProvider);
      ref.read(activeWorkspaceIdProvider.notifier).state = workspace.id;
    } on AppException catch (e) {
      if (context.mounted) AppToast.error(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final workspacesAsync = ref.watch(workspaceListProvider);
    final activeId = ref.watch(activeWorkspaceIdProvider);

    return SheetScaffold(
      title: 'Workspaces',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          workspacesAsync.when(
            data: (workspaces) => Column(
              children: [
                for (final workspace in workspaces)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: InkWell(
                      borderRadius: Radii.smAll,
                      onTap: () {
                        ref.read(activeWorkspaceIdProvider.notifier).state =
                            workspace.id;
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: workspace.id == activeId
                              ? Brand.primaryLight
                              : c.surface2,
                          borderRadius: Radii.smAll,
                          border: Border.all(
                            color: workspace.id == activeId
                                ? Brand.primary
                                : c.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                workspace.name,
                                style: TextStyle(
                                  fontSize: rem(0.85),
                                  fontWeight: FontWeight.w600,
                                  color: workspace.id == activeId
                                      ? Brand.primary
                                      : c.text,
                                ),
                              ),
                            ),
                            if (workspace.id == activeId)
                              const Icon(
                                Icons.check,
                                size: 16,
                                color: Brand.primary,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error: $e'),
            ),
          ),
          const SizedBox(height: 10),
          AppButton.secondary(
            '+ Create Workspace',
            expand: true,
            onPressed: () => _createWorkspace(context, ref),
          ),
        ],
      ),
    );
  }
}

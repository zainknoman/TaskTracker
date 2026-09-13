import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/exceptions.dart';
import '../../providers/workspace_providers.dart';
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
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New workspace'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Workspace name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      final workspace = await ref.read(workspaceRepositoryProvider).create(name);
      ref.invalidate(workspaceListProvider);
      ref.read(activeWorkspaceIdProvider.notifier).state = workspace.id;
    } on AppException catch (e) {
      if (context.mounted) AppToast.error(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspacesAsync = ref.watch(workspaceListProvider);
    final activeId = ref.watch(activeWorkspaceIdProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Workspaces', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            workspacesAsync.when(
              data: (workspaces) => Column(
                children: [
                  for (final workspace in workspaces)
                    ListTile(
                      title: Text(workspace.name),
                      trailing: workspace.id == activeId ? const Icon(Icons.check) : null,
                      onTap: () {
                        ref.read(activeWorkspaceIdProvider.notifier).state = workspace.id;
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: Text('Error: $e')),
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Create workspace'),
              onTap: () => _createWorkspace(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

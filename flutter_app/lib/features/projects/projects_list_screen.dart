import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/permissions_provider.dart';
import '../../providers/project_providers.dart';
import '../../providers/workspace_providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/priority_badge.dart';
import '../../widgets/status_badge.dart';
import 'project_form_sheet.dart';

class ProjectsListScreen extends ConsumerWidget {
  const ProjectsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceId = ref.watch(activeWorkspaceIdProvider);
    final permissions = ref.watch(permissionsProvider);

    if (workspaceId == null) {
      return const Scaffold(body: EmptyState(icon: Icons.folder_open, message: 'No workspace selected'));
    }

    final projectsAsync = ref.watch(projectsProvider(workspaceId));

    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      body: projectsAsync.when(
        data: (projects) {
          if (projects.isEmpty) {
            return const EmptyState(icon: Icons.folder_open, message: 'No projects yet');
          }
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.95,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              return Card(
                child: InkWell(
                  onTap: () => context.push('/projects/${project.id}'),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(project.name,
                            style: Theme.of(context).textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                        if (project.code != null) ...[
                          const SizedBox(height: 4),
                          Text(project.code!, style: Theme.of(context).textTheme.bodySmall),
                        ],
                        const Spacer(),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            StatusBadge(status: project.status),
                            PriorityBadge(priority: project.priority),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: permissions.canEdit
          ? FloatingActionButton(
              heroTag: 'projectsListFab',
              onPressed: () => ProjectFormSheet.show(context),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

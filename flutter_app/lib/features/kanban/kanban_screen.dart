import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/project.dart';
import '../../providers/project_providers.dart';
import '../../providers/task_providers.dart';
import '../../providers/workspace_providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/page_layout.dart';
import '../../widgets/view_header.dart';
import 'kanban_board.dart';

class KanbanScreen extends ConsumerStatefulWidget {
  const KanbanScreen({super.key});

  @override
  ConsumerState<KanbanScreen> createState() => _KanbanScreenState();
}

class _KanbanScreenState extends ConsumerState<KanbanScreen> {
  String? _projectFilter;

  @override
  Widget build(BuildContext context) {
    final workspaceId = ref.watch(activeWorkspaceIdProvider);
    if (workspaceId == null) {
      return const EmptyState(
        icon: Icons.grid_view_rounded,
        message: 'No workspace selected',
      );
    }

    final tasksAsync = ref.watch(tasksProvider(workspaceId));
    final projects =
        ref.watch(projectsProvider(workspaceId)).value ?? const <Project>[];

    return tasksAsync.when(
      data: (tasks) {
        final visible = _projectFilter == null
            ? tasks
            : tasks.where((t) => t.projectId == _projectFilter).toList();
        return ListView(
          padding: pagePadding(context),
          children: [
            ViewHeader(
              title: 'Kanban Board',
              actions: [
                FilterSelect<String>(
                  value: _projectFilter,
                  allLabel: 'All Projects',
                  options: [for (final p in projects) (p.id, p.name)],
                  onChanged: (v) => setState(() => _projectFilter = v),
                ),
              ],
            ),
            KanbanBoard(tasks: visible),
          ],
        );
      },
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(e),
    );
  }
}

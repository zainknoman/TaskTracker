import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/exceptions.dart';
import '../../models/task.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/task_providers.dart';
import '../../providers/workspace_providers.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/priority_badge.dart';

const _kanbanColumns = [
  ('pending', 'Pending'),
  ('in_progress', 'In Progress'),
  ('completed', 'Completed'),
  ('blocked', 'Blocked'),
];

class KanbanScreen extends ConsumerWidget {
  const KanbanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceId = ref.watch(activeWorkspaceIdProvider);
    final permissions = ref.watch(permissionsProvider);

    if (workspaceId == null) {
      return const Scaffold(body: EmptyState(icon: Icons.view_kanban_outlined, message: 'No workspace selected'));
    }

    final tasksAsync = ref.watch(tasksProvider(workspaceId));

    return Scaffold(
      appBar: AppBar(title: const Text('Kanban')),
      body: tasksAsync.when(
        data: (tasks) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final column in _kanbanColumns)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _KanbanColumn(
                      status: column.$1,
                      title: column.$2,
                      tasks: tasks.where((t) => t.status == column.$1).toList(),
                      canEdit: permissions.canEdit,
                      onDropTask: (task, newStatus) async {
                        if (!permissions.canEdit) {
                          AppToast.error(context, "Guests can't move tasks.");
                          return;
                        }
                        try {
                          await ref.read(taskRepositoryProvider).update(task.copyWith(status: newStatus));
                        } on AppException catch (e) {
                          if (context.mounted) AppToast.error(context, e.message);
                        }
                      },
                    ),
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  final String status;
  final String title;
  final List<Task> tasks;
  final bool canEdit;
  final void Function(Task task, String newStatus) onDropTask;

  const _KanbanColumn({
    required this.status,
    required this.title,
    required this.tasks,
    required this.canEdit,
    required this.onDropTask,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: DragTarget<Task>(
        onAcceptWithDetails: (details) => onDropTask(details.data, status),
        builder: (context, candidateData, rejectedData) {
          final highlighted = candidateData.isNotEmpty;
          return Container(
            decoration: BoxDecoration(
              color: highlighted
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
                  : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Text('$title (${tasks.length})',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                ),
                for (final task in tasks)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: canEdit
                        ? LongPressDraggable<Task>(
                            data: task,
                            feedback: Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(width: 240, child: _TaskCard(task: task)),
                            ),
                            childWhenDragging: Opacity(opacity: 0.4, child: _TaskCard(task: task)),
                            child: _TaskCard(task: task),
                          )
                        : _TaskCard(task: task),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Task task;
  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            PriorityBadge(priority: task.priority),
          ],
        ),
      ),
    );
  }
}

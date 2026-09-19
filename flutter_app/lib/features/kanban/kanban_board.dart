import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/tokens.dart';
import '../../core/ui_helpers.dart';
import '../../data/exceptions.dart';
import '../../models/project.dart';
import '../../models/task.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/project_providers.dart';
import '../../providers/task_providers.dart';
import '../../providers/workspace_providers.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/priority_badge.dart';

/// The web `.kanban-board`: four status columns, horizontally scrollable, drag (long-press) to move.
/// Used by the Kanban view and the project detail "Kanban" tab.
class KanbanBoard extends ConsumerWidget {
  final List<Task> tasks;
  const KanbanBoard({super.key, required this.tasks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(permissionsProvider);
    final workspaceId = ref.watch(activeWorkspaceIdProvider);
    final projects = workspaceId != null
        ? ref.watch(projectsProvider(workspaceId)).value ?? const <Project>[]
        : const <Project>[];
    final projectById = {for (final p in projects) p.id: p};

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, column) in taskStatusOptions.indexed)
            Padding(
              padding: EdgeInsets.only(
                right: i == taskStatusOptions.length - 1 ? 0 : 14,
              ),
              child: _KanbanColumn(
                status: column.$1,
                title: column.$2,
                tasks: tasks.where((t) => t.status == column.$1).toList(),
                canEdit: permissions.canEdit,
                projectById: projectById,
                onDropTask: (task, newStatus) async {
                  if (!permissions.canEdit) {
                    AppToast.error(context, "Guests can't move tasks.");
                    return;
                  }
                  try {
                    await ref
                        .read(taskRepositoryProvider)
                        .update(task.copyWith(status: newStatus));
                  } on AppException catch (e) {
                    if (context.mounted) AppToast.error(context, e.message);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  final String status;
  final String title;
  final List<Task> tasks;
  final bool canEdit;
  final Map<String, Project> projectById;
  final void Function(Task task, String newStatus) onDropTask;

  const _KanbanColumn({
    required this.status,
    required this.title,
    required this.tasks,
    required this.canEdit,
    required this.projectById,
    required this.onDropTask,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      width: 268,
      child: DragTarget<Task>(
        onAcceptWithDetails: (details) => onDropTask(details.data, status),
        builder: (context, candidateData, rejectedData) {
          final highlighted = candidateData.isNotEmpty;
          return Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: c.surface2,
              borderRadius: Radii.lgAll,
              border: Border.all(
                color: highlighted ? Brand.primary : c.border,
                width: highlighted ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: c.border)),
                  ),
                  child: Row(
                    children: [
                      ColorDot(
                        statusMeta[status]?.dot ?? Brand.primary,
                        size: 9,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: rem(0.85),
                            fontWeight: FontWeight.w700,
                            color: c.text,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: c.border,
                          borderRadius: Radii.pillAll,
                        ),
                        child: Text(
                          '${tasks.length}',
                          style: TextStyle(
                            fontSize: rem(0.68),
                            fontWeight: FontWeight.w700,
                            color: c.text3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 180),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        for (final (i, task) in tasks.indexed)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: i == tasks.length - 1 ? 0 : 7,
                            ),
                            child: canEdit
                                ? LongPressDraggable<Task>(
                                    data: task,
                                    feedback: Material(
                                      color: Colors.transparent,
                                      child: SizedBox(
                                        width: 252,
                                        child: _TaskCard(
                                          task: task,
                                          projectById: projectById,
                                          lifted: true,
                                        ),
                                      ),
                                    ),
                                    childWhenDragging: Opacity(
                                      opacity: .4,
                                      child: _TaskCard(
                                        task: task,
                                        projectById: projectById,
                                      ),
                                    ),
                                    child: _TaskCard(
                                      task: task,
                                      projectById: projectById,
                                    ),
                                  )
                                : _TaskCard(
                                    task: task,
                                    projectById: projectById,
                                  ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Web `.kanban-card`.
class _TaskCard extends StatelessWidget {
  final Task task;
  final Map<String, Project> projectById;
  final bool lifted;
  const _TaskCard({
    required this.task,
    required this.projectById,
    this.lifted = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final project = projectById[task.projectId];
    final overdue = isOverdue(task);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: Radii.mdAll,
        border: Border.all(color: c.border),
        boxShadow: lifted ? c.shadowLg : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: Radii.mdAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/tasks/${task.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: rem(0.85),
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                          color: c.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PriorityBadge(priority: task.priority),
                  ],
                ),
                if (project != null) ...[
                  const SizedBox(height: 5),
                  ProjectPill(
                    name: project.name,
                    color: parseHex(project.color),
                  ),
                ],
                if (task.dueDate != null ||
                    (task.ba != null && task.ba!.isNotEmpty)) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        task.ba ?? '',
                        style: TextStyle(fontSize: rem(0.72), color: c.text3),
                      ),
                      if (task.dueDate != null)
                        Text(
                          fmtDate(task.dueDate),
                          style: TextStyle(
                            fontSize: rem(0.72),
                            color: overdue ? Brand.danger : c.text3,
                          ),
                        ),
                    ],
                  ),
                ],
                if (task.tags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 3,
                    runSpacing: 3,
                    children: [
                      for (final (i, t) in task.tags.indexed)
                        TagChip(t, index: i),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

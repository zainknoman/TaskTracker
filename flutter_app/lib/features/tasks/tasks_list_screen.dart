import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui_helpers.dart';
import '../../data/task_transfer_service.dart';
import '../../widgets/app_toast.dart';
import '../../providers/auth_providers.dart';
import '../../models/project.dart';
import '../../models/task.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/project_providers.dart';
import '../../providers/task_providers.dart';
import '../../providers/workspace_providers.dart';
import '../../widgets/app_button.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/page_layout.dart';
import '../../widgets/task_row.dart';
import '../../widgets/view_header.dart';
import 'task_form_sheet.dart';

class TasksListScreen extends ConsumerStatefulWidget {
  const TasksListScreen({super.key});

  @override
  ConsumerState<TasksListScreen> createState() => _TasksListScreenState();
}

class _TasksListScreenState extends ConsumerState<TasksListScreen> {
  final _transfer = TaskTransferService();
  String? _projectFilter;
  String? _statusFilter;
  String? _priorityFilter;

  bool get _hasFilters =>
      _projectFilter != null ||
      _statusFilter != null ||
      _priorityFilter != null;

  List<Task> _applyFilters(List<Task> tasks) {
    var filtered = tasks;
    if (_projectFilter != null) {
      filtered = filtered.where((t) => t.projectId == _projectFilter).toList();
    }
    if (_statusFilter != null) {
      filtered = filtered.where((t) => t.status == _statusFilter).toList();
    }
    if (_priorityFilter != null) {
      filtered = filtered.where((t) => t.priority == _priorityFilter).toList();
    }
    filtered.sort((a, b) {
      final aDate = a.dueDate;
      final bDate = b.dueDate;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return aDate.compareTo(bDate);
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final workspaceId = ref.watch(activeWorkspaceIdProvider);
    final permissions = ref.watch(permissionsProvider);

    if (workspaceId == null) {
      return const EmptyState(
        icon: Icons.assignment_turned_in,
        message: 'No workspace selected',
      );
    }

    final tasksAsync = ref.watch(tasksProvider(workspaceId));
    final projects =
        ref.watch(projectsProvider(workspaceId)).value ?? const <Project>[];
    final projectById = {for (final p in projects) p.id: p};

    return tasksAsync.when(
      data: (tasks) {
        final filtered = _applyFilters(tasks);
        return ListView(
          padding: pagePadding(context),
          children: [
            ViewHeader(
              title: 'All Tasks',
              subtitle:
                  '${filtered.length} task${filtered.length == 1 ? '' : 's'}',
              actions: [
                AppButton.secondary(
                  'Export JSON',
                  small: true,
                  onPressed: () async {
                    try {
                      await _transfer.exportWorkspace(workspaceId);
                    } catch (e) {
                      if (mounted) AppToast.error(context, e.toString());
                    }
                  },
                ),
                AppButton.secondary(
                  'Import Task',
                  small: true,
                  onPressed: () async {
                    final userId = ref.read(currentUserProvider)?.id;
                    if (userId == null) return;
                    try {
                      await _transfer.importTask(workspaceId, userId);
                      ref.invalidate(tasksProvider(workspaceId));
                      if (mounted) AppToast.success(context, 'Task imported');
                    } on Exception catch (e) {
                      if (mounted) AppToast.error(context, e.toString());
                    }
                  },
                ),
                if (permissions.canEdit)
                  AppButton(
                    '+ New Task',
                    onPressed: () => TaskFormSheet.show(context),
                  ),
              ],
            ),
            FilterBar(
              children: [
                FilterSelect<String>(
                  value: _projectFilter,
                  allLabel: 'All Projects',
                  options: [for (final p in projects) (p.id, p.name)],
                  onChanged: (v) => setState(() => _projectFilter = v),
                ),
                FilterSelect<String>(
                  value: _statusFilter,
                  allLabel: 'All Status',
                  options: taskStatusOptions,
                  onChanged: (v) => setState(() => _statusFilter = v),
                ),
                FilterSelect<String>(
                  value: _priorityFilter,
                  allLabel: 'All Priority',
                  options: priorityOptions,
                  onChanged: (v) => setState(() => _priorityFilter = v),
                ),
                if (_hasFilters)
                  AppButton.ghost(
                    '✕ Clear',
                    small: true,
                    onPressed: () => setState(() {
                      _projectFilter = null;
                      _statusFilter = null;
                      _priorityFilter = null;
                    }),
                  ),
              ],
            ),
            if (filtered.isEmpty)
              TaskTable(
                rows: [
                  EmptyState(
                    icon: Icons.check_circle_outline,
                    message: 'No tasks found',
                    hint: 'Try adjusting filters or create a new task',
                    action: permissions.canEdit
                        ? AppButton(
                            '+ Create Task',
                            onPressed: () => TaskFormSheet.show(context),
                          )
                        : null,
                  ),
                ],
              )
            else
              TaskTable(
                rows: [
                  for (final (i, task) in filtered.indexed)
                    TaskRow(
                      task: task,
                      projectName: projectById[task.projectId]?.name,
                      projectColor: parseHex(
                        projectById[task.projectId]?.color,
                      ),
                      last: i == filtered.length - 1,
                      onTap: () => context.push('/tasks/${task.id}'),
                    ),
                ],
              ),
          ],
        );
      },
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(e),
    );
  }
}

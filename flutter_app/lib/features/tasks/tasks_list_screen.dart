import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/task.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/task_providers.dart';
import '../../providers/workspace_providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/priority_badge.dart';
import '../../widgets/status_badge.dart';
import 'task_form_sheet.dart';

class TasksListScreen extends ConsumerStatefulWidget {
  const TasksListScreen({super.key});

  @override
  ConsumerState<TasksListScreen> createState() => _TasksListScreenState();
}

class _TasksListScreenState extends ConsumerState<TasksListScreen> {
  String? _statusFilter;
  String? _priorityFilter;

  List<Task> _applyFilters(List<Task> tasks) {
    var filtered = tasks;
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
      return const Scaffold(body: EmptyState(icon: Icons.task_outlined, message: 'No workspace selected'));
    }

    final tasksAsync = ref.watch(tasksProvider(workspaceId));

    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final status in const ['pending', 'in_progress', 'completed', 'blocked'])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text(status.replaceAll('_', ' ')),
                      selected: _statusFilter == status,
                      onSelected: (selected) => setState(() => _statusFilter = selected ? status : null),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: tasksAsync.when(
              data: (tasks) {
                final filtered = _applyFilters(tasks);
                if (filtered.isEmpty) {
                  return const EmptyState(icon: Icons.task_outlined, message: 'No tasks found');
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final task = filtered[index];
                    return ListTile(
                      title: Text(task.title),
                      subtitle: task.dueDate != null
                          ? Text('Due ${task.dueDate!.toLocal()}'.split(' ').first)
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PriorityBadge(priority: task.priority),
                          const SizedBox(width: 6),
                          StatusBadge(status: task.status),
                        ],
                      ),
                      onTap: () => context.push('/tasks/${task.id}'),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: permissions.canEdit
          ? FloatingActionButton(
              heroTag: 'tasksListFab',
              onPressed: () => TaskFormSheet.show(context),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

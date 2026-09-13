import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/project.dart';
import '../../models/task.dart';
import '../../providers/project_providers.dart';
import '../../providers/task_providers.dart';
import '../../providers/workspace_providers.dart';
import '../../widgets/empty_state.dart';

const double _dayWidth = 36;
const double _rowHeight = 44;
const double _labelWidth = 160;

class GanttScreen extends ConsumerStatefulWidget {
  const GanttScreen({super.key});

  @override
  ConsumerState<GanttScreen> createState() => _GanttScreenState();
}

class _GanttScreenState extends ConsumerState<GanttScreen> {
  String? _selectedProjectId;

  @override
  Widget build(BuildContext context) {
    final workspaceId = ref.watch(activeWorkspaceIdProvider);
    if (workspaceId == null) {
      return const Scaffold(body: EmptyState(icon: Icons.view_timeline_outlined, message: 'No workspace selected'));
    }

    final projectsAsync = ref.watch(projectsProvider(workspaceId));
    final tasksAsync = ref.watch(tasksProvider(workspaceId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gantt'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: projectsAsync.maybeWhen(
            data: (projects) {
              if (projects.isEmpty) return const SizedBox.shrink();
              _selectedProjectId ??= projects.first.id;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedProjectId,
                  items: [
                    for (final p in projects) DropdownMenuItem(value: p.id, child: Text(p.name)),
                  ],
                  onChanged: (v) => setState(() => _selectedProjectId = v),
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ),
      ),
      body: projectsAsync.when(
        data: (projects) {
          if (projects.isEmpty) {
            return const EmptyState(icon: Icons.view_timeline_outlined, message: 'No projects yet');
          }
          final project = projects.firstWhere((p) => p.id == _selectedProjectId, orElse: () => projects.first);
          return tasksAsync.when(
            data: (allTasks) {
              final tasks = allTasks.where((t) => t.projectId == project.id).toList();
              if (tasks.isEmpty) {
                return const EmptyState(icon: Icons.view_timeline_outlined, message: 'No tasks in this project');
              }
              return _GanttChart(project: project, tasks: tasks);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _GanttChart extends StatelessWidget {
  final Project project;
  final List<Task> tasks;
  const _GanttChart({required this.project, required this.tasks});

  @override
  Widget build(BuildContext context) {
    DateTime rangeStart = tasks
        .map((t) => t.startDate ?? t.createdAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    DateTime rangeEnd = tasks
        .map((t) => t.dueDate ?? t.startDate ?? t.createdAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    if (!rangeEnd.isAfter(rangeStart)) rangeEnd = rangeStart.add(const Duration(days: 1));

    final totalDays = rangeEnd.difference(rangeStart).inDays + 1;
    final totalWidth = totalDays * _dayWidth;

    // Group by milestone (tasks without a milestone go under "Unassigned").
    final Map<String, List<Task>> grouped = {};
    for (final task in tasks) {
      final key = task.milestoneId ?? 'unassigned';
      grouped.putIfAbsent(key, () => []).add(task);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _labelWidth + totalWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GanttHeaderRow(rangeStart: rangeStart, totalDays: totalDays),
              for (final entry in grouped.entries) ...[
                Container(
                  width: _labelWidth + totalWidth,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    entry.key == 'unassigned' ? 'Unassigned' : entry.key,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                for (final task in entry.value)
                  _GanttRow(task: task, rangeStart: rangeStart, totalWidth: totalWidth),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GanttHeaderRow extends StatelessWidget {
  final DateTime rangeStart;
  final int totalDays;
  const _GanttHeaderRow({required this.rangeStart, required this.totalDays});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: _labelWidth, height: 32),
        for (var i = 0; i < totalDays; i++)
          SizedBox(
            width: _dayWidth,
            height: 32,
            child: Center(
              child: Text(
                DateFormat('d').format(rangeStart.add(Duration(days: i))),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
      ],
    );
  }
}

class _GanttRow extends StatelessWidget {
  final Task task;
  final DateTime rangeStart;
  final double totalWidth;
  const _GanttRow({required this.task, required this.rangeStart, required this.totalWidth});

  Color _priorityColor() {
    switch (task.priority) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.deepOrange;
      case 'medium':
        return Colors.amber.shade700;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = task.startDate ?? task.createdAt;
    final end = task.dueDate ?? start.add(const Duration(days: 1));
    final offsetDays = start.difference(rangeStart).inDays.clamp(0, 100000);
    final durationDays = (end.difference(start).inDays + 1).clamp(1, 100000);
    final color = _priorityColor();

    return SizedBox(
      height: _rowHeight,
      child: Row(
        children: [
          SizedBox(
            width: _labelWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
            ),
          ),
          SizedBox(
            width: totalWidth,
            child: Stack(
              children: [
                Positioned(
                  left: offsetDays * _dayWidth,
                  top: 8,
                  width: durationDays * _dayWidth,
                  height: _rowHeight - 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: color),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (task.progress.clamp(0, 100)) / 100,
                      child: Container(
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

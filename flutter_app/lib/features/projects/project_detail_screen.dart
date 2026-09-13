import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/milestone_repository.dart';
import '../../data/sprint_repository.dart';
import '../../models/milestone.dart';
import '../../models/project.dart';
import '../../models/sprint.dart';
import '../../providers/project_providers.dart';
import '../../providers/task_providers.dart';
import '../../providers/workspace_providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/priority_badge.dart';
import '../../widgets/status_badge.dart';
import 'project_form_sheet.dart';

final _milestoneRepositoryProvider = Provider<MilestoneRepository>((ref) => MilestoneRepository());
final _sprintRepositoryProvider = Provider<SprintRepository>((ref) => SprintRepository());

final _milestonesForProjectProvider = FutureProvider.family<List<Milestone>, String>((ref, projectId) {
  return ref.watch(_milestoneRepositoryProvider).listForProject(projectId);
});

final _sprintsForProjectProvider = FutureProvider.family<List<Sprint>, String>((ref, projectId) {
  return ref.watch(_sprintRepositoryProvider).listForProject(projectId);
});

class ProjectDetailScreen extends ConsumerWidget {
  final String projectId;
  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceId = ref.watch(activeWorkspaceIdProvider);
    if (workspaceId == null) {
      return const Scaffold(body: EmptyState(icon: Icons.folder_open, message: 'No workspace selected'));
    }

    final projectsAsync = ref.watch(projectsProvider(workspaceId));

    return projectsAsync.when(
      data: (projects) {
        Project? project;
        for (final p in projects) {
          if (p.id == projectId) project = p;
        }
        if (project == null) {
          return const Scaffold(body: EmptyState(icon: Icons.error_outline, message: 'Project not found'));
        }
        return _ProjectDetailBody(project: project);
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}

class _ProjectDetailBody extends ConsumerWidget {
  final Project project;
  const _ProjectDetailBody({required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(project.name),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => ProjectFormSheet.show(context, existing: project),
            ),
          ],
          bottom: const TabBar(tabs: [
            Tab(text: 'Overview'),
            Tab(text: 'Tasks'),
            Tab(text: 'Milestones'),
            Tab(text: 'Sprints'),
          ]),
        ),
        body: TabBarView(
          children: [
            _OverviewTab(project: project),
            _TasksTab(project: project),
            _MilestonesTab(projectId: project.id),
            _SprintsTab(projectId: project.id),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final Project project;
  const _OverviewTab({required this.project});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(spacing: 8, children: [
          StatusBadge(status: project.status),
          PriorityBadge(priority: project.priority),
        ]),
        const SizedBox(height: 16),
        if (project.description != null) Text(project.description!),
        const SizedBox(height: 16),
        if (project.client != null) _InfoRow(label: 'Client', value: project.client!),
        if (project.department != null) _InfoRow(label: 'Department', value: project.department!),
        if (project.pm != null) _InfoRow(label: 'PM', value: project.pm!),
        if (project.baTeam != null) _InfoRow(label: 'BA Team', value: project.baTeam!),
        if (project.budget != null) _InfoRow(label: 'Budget', value: project.budget.toString()),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _TasksTab extends ConsumerWidget {
  final Project project;
  const _TasksTab({required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider(project.workspaceId));
    return tasksAsync.when(
      data: (tasks) {
        final projectTasks = tasks.where((t) => t.projectId == project.id).toList();
        if (projectTasks.isEmpty) {
          return const EmptyState(icon: Icons.task_outlined, message: 'No tasks in this project');
        }
        return ListView.builder(
          itemCount: projectTasks.length,
          itemBuilder: (context, index) {
            final task = projectTasks[index];
            return ListTile(
              title: Text(task.title),
              trailing: StatusBadge(status: task.status),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _MilestonesTab extends ConsumerWidget {
  final String projectId;
  const _MilestonesTab({required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final milestonesAsync = ref.watch(_milestonesForProjectProvider(projectId));
    return milestonesAsync.when(
      data: (milestones) {
        if (milestones.isEmpty) {
          return const EmptyState(icon: Icons.flag_outlined, message: 'No milestones yet');
        }
        return ListView.builder(
          itemCount: milestones.length,
          itemBuilder: (context, index) {
            final m = milestones[index];
            return ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(m.title),
              subtitle: m.dueDate != null ? Text('Due ${m.dueDate!.toLocal()}'.split(' ').first) : null,
              trailing: StatusBadge(status: m.status),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _SprintsTab extends ConsumerWidget {
  final String projectId;
  const _SprintsTab({required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sprintsAsync = ref.watch(_sprintsForProjectProvider(projectId));
    return sprintsAsync.when(
      data: (sprints) {
        if (sprints.isEmpty) {
          return const EmptyState(icon: Icons.directions_run, message: 'No sprints yet');
        }
        return ListView.builder(
          itemCount: sprints.length,
          itemBuilder: (context, index) {
            final s = sprints[index];
            return ListTile(
              leading: const Icon(Icons.directions_run),
              title: Text(s.name),
              trailing: StatusBadge(status: s.status),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

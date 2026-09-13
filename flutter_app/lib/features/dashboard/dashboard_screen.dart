import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/task.dart';
import '../../providers/member_providers.dart';
import '../../providers/project_providers.dart';
import '../../providers/task_providers.dart';
import '../../providers/workspace_providers.dart';
import '../../widgets/empty_state.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceId = ref.watch(activeWorkspaceIdProvider);
    if (workspaceId == null) {
      return const Scaffold(body: EmptyState(icon: Icons.dashboard_outlined, message: 'No workspace selected'));
    }

    final tasksAsync = ref.watch(tasksProvider(workspaceId));
    final projectsAsync = ref.watch(projectsProvider(workspaceId));
    final membersAsync = ref.watch(membersProvider(workspaceId));

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: tasksAsync.when(
        data: (tasks) {
          final total = tasks.length;
          final inProgress = tasks.where((t) => t.status == 'in_progress').length;
          final completed = tasks.where((t) => t.status == 'completed').length;
          final now = DateTime.now();
          final overdue = tasks
              .where((t) => t.dueDate != null && t.dueDate!.isBefore(now) && t.status != 'completed')
              .length;

          final upcoming = tasks.where((t) {
            if (t.dueDate == null) return false;
            final diff = t.dueDate!.difference(now).inDays;
            return diff >= 0 && diff <= 7;
          }).toList()
            ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.6,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _StatCard(label: 'Total tasks', value: total, color: Colors.indigo),
                  _StatCard(label: 'In progress', value: inProgress, color: Colors.blue),
                  _StatCard(label: 'Completed', value: completed, color: Colors.green),
                  _StatCard(label: 'Overdue', value: overdue, color: Colors.red),
                ],
              ),
              const SizedBox(height: 24),
              Text('Upcoming deadlines', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (upcoming.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Nothing due in the next 7 days'),
                )
              else
                for (final task in upcoming)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: Text(task.title),
                    subtitle: Text('Due ${task.dueDate!.toLocal()}'.split(' ').first),
                  ),
              const SizedBox(height: 24),
              Text('Team workload', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              membersAsync.when(
                data: (members) => Column(
                  children: [
                    for (final member in members)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          child: Text((member.displayName ?? '?').substring(0, 1).toUpperCase()),
                        ),
                        title: Text(member.displayName ?? 'Unnamed'),
                        trailing: Text('${_countForAssignee(tasks, member.userId)} tasks'),
                      ),
                  ],
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
              const SizedBox(height: 24),
              projectsAsync.maybeWhen(
                data: (projects) => Text('${projects.length} projects in this workspace'),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  int _countForAssignee(List<Task> tasks, String userId) =>
      tasks.where((t) => t.assigneeId == userId).length;
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$value', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: color)),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

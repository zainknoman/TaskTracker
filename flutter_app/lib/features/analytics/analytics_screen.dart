import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/task.dart';
import '../../providers/member_providers.dart';
import '../../providers/task_providers.dart';
import '../../providers/workspace_providers.dart';
import '../../widgets/empty_state.dart';

const _statusColors = {
  'pending': Colors.orange,
  'in_progress': Colors.blue,
  'completed': Colors.green,
  'blocked': Colors.red,
};

const _priorityColors = {
  'low': Colors.blueGrey,
  'medium': Colors.amber,
  'high': Colors.deepOrange,
  'critical': Colors.red,
};

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceId = ref.watch(activeWorkspaceIdProvider);
    if (workspaceId == null) {
      return const Scaffold(body: EmptyState(icon: Icons.bar_chart, message: 'No workspace selected'));
    }

    final tasksAsync = ref.watch(tasksProvider(workspaceId));
    final membersAsync = ref.watch(membersProvider(workspaceId));

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: tasksAsync.when(
        data: (tasks) {
          if (tasks.isEmpty) {
            return const EmptyState(icon: Icons.bar_chart, message: 'No tasks to analyze yet');
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Status distribution', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              SizedBox(height: 180, child: _StatusPieChart(tasks: tasks)),
              const SizedBox(height: 24),
              Text('Priority distribution', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              SizedBox(height: 180, child: _PriorityPieChart(tasks: tasks)),
              const SizedBox(height: 24),
              Text('Workload by member', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              membersAsync.when(
                data: (members) => SizedBox(
                  height: 220,
                  child: _WorkloadBarChart(
                    tasks: tasks,
                    memberNames: {for (final m in members) m.userId: m.displayName ?? 'Unnamed'},
                  ),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _StatusPieChart extends StatelessWidget {
  final List<Task> tasks;
  const _StatusPieChart({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final t in tasks) {
      counts[t.status] = (counts[t.status] ?? 0) + 1;
    }
    return PieChart(
      PieChartData(
        sections: [
          for (final entry in counts.entries)
            PieChartSectionData(
              value: entry.value.toDouble(),
              title: '${entry.value}',
              color: _statusColors[entry.key] ?? Colors.grey,
              radius: 60,
            ),
        ],
      ),
    );
  }
}

class _PriorityPieChart extends StatelessWidget {
  final List<Task> tasks;
  const _PriorityPieChart({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final t in tasks) {
      counts[t.priority] = (counts[t.priority] ?? 0) + 1;
    }
    return PieChart(
      PieChartData(
        sections: [
          for (final entry in counts.entries)
            PieChartSectionData(
              value: entry.value.toDouble(),
              title: '${entry.value}',
              color: _priorityColors[entry.key] ?? Colors.grey,
              radius: 60,
            ),
        ],
      ),
    );
  }
}

class _WorkloadBarChart extends StatelessWidget {
  final List<Task> tasks;
  final Map<String, String> memberNames;
  const _WorkloadBarChart({required this.tasks, required this.memberNames});

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final t in tasks) {
      if (t.assigneeId == null) continue;
      counts[t.assigneeId!] = (counts[t.assigneeId!] ?? 0) + 1;
    }
    final entries = counts.entries.toList();
    if (entries.isEmpty) {
      return const EmptyState(icon: Icons.bar_chart, message: 'No tasks assigned yet');
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        barGroups: [
          for (var i = 0; i < entries.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(toY: entries[i].value.toDouble(), color: Theme.of(context).colorScheme.primary),
            ]),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= entries.length) return const SizedBox.shrink();
                final name = memberNames[entries[index].key] ?? 'Unknown';
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(name, style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
      ),
    );
  }
}

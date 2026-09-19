import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens.dart';
import '../../core/ui_helpers.dart';
import '../../models/project.dart';
import '../../models/task.dart';
import '../../models/workspace_member.dart';
import '../../providers/member_providers.dart';
import '../../providers/project_providers.dart';
import '../../providers/task_providers.dart';
import '../../providers/workspace_providers.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/page_layout.dart';
import '../../widgets/view_header.dart';

const _statusColors = {
  'pending': Color(0xFFFBBF24),
  'inprogress': Color(0xFF60A5FA),
  'completed': Color(0xFF34D399),
  'blocked': Color(0xFFF87171),
};

const _priorityColors = {
  'low': Color(0xFF34D399),
  'medium': Color(0xFF60A5FA),
  'high': Color(0xFFFCD34D),
  'critical': Color(0xFFF87171),
};

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceId = ref.watch(activeWorkspaceIdProvider);
    if (workspaceId == null) {
      return const SubPage(
        crumbs: ['Analytics'],
        body: EmptyState(
          icon: Icons.bar_chart,
          message: 'No workspace selected',
        ),
      );
    }

    final tasksAsync = ref.watch(tasksProvider(workspaceId));
    final projects =
        ref.watch(projectsProvider(workspaceId)).value ?? const <Project>[];
    final members =
        ref.watch(membersProvider(workspaceId)).value ??
        const <WorkspaceMember>[];

    return SubPage(
      crumbs: const ['Analytics'],
      body: tasksAsync.when(
        data: (tasks) =>
            _AnalyticsBody(tasks: tasks, projects: projects, members: members),
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(e),
      ),
    );
  }
}

class _AnalyticsBody extends StatelessWidget {
  final List<Task> tasks;
  final List<Project> projects;
  final List<WorkspaceMember> members;
  const _AnalyticsBody({
    required this.tasks,
    required this.projects,
    required this.members,
  });

  @override
  Widget build(BuildContext context) {
    final total = tasks.length;
    int byStatus(String s) => tasks.where((t) => t.status == s).length;

    final workload = <WorkspaceMember, int>{};
    for (final m in members) {
      final n = tasks.where((t) => t.assigneeId == m.userId).length;
      if (n > 0) workload[m] = n;
    }
    final workloadEntries = workload.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final kpis = [
      (
        'Completion Rate',
        total == 0 ? '—' : '${(byStatus('completed') / total * 100).round()}%',
        Brand.success,
      ),
      (
        'Blocked Rate',
        total == 0 ? '—' : '${(byStatus('blocked') / total * 100).round()}%',
        Brand.danger,
      ),
      ('Overdue Tasks', '${tasks.where(isOverdue).length}', Brand.warning),
      (
        'Critical Tasks',
        '${tasks.where((t) => t.priority == 'critical').length}',
        Brand.info,
      ),
      (
        'Total Projects',
        '${projects.where((p) => p.status == 'active').length} active',
        Brand.primary,
      ),
      (
        'Total Hours Est',
        '${tasks.fold<num>(0, (a, t) => a + (t.estimatedHours ?? 0))}h',
        const Color(0xFF0891B2),
      ),
    ];

    final wide = MediaQuery.sizeOf(context).width >= 760;
    final cards = [
      _AnalyticsCard(
        title: 'Tasks by Status',
        child: Column(
          children: [
            for (final s in taskStatusOptions)
              _HBar(
                label: s.$2,
                value:
                    '${byStatus(s.$1)} (${total == 0 ? 0 : (byStatus(s.$1) / total * 100).round()}%)',
                fraction: total == 0 ? 0 : byStatus(s.$1) / total,
                color: _statusColors[s.$1]!,
              ),
          ],
        ),
      ),
      _AnalyticsCard(
        title: 'Tasks by Priority',
        child: Column(
          children: [
            for (final p in priorityOptions)
              Builder(
                builder: (_) {
                  final n = tasks.where((t) => t.priority == p.$1).length;
                  return _HBar(
                    label: p.$2,
                    value: '$n',
                    fraction: total == 0 ? 0 : n / total,
                    color: _priorityColors[p.$1]!,
                  );
                },
              ),
          ],
        ),
      ),
      _AnalyticsCard(
        title: 'Project Progress',
        child: projects.where((p) => p.status != 'archived').isEmpty
            ? const NoData('No projects')
            : Column(
                children: [
                  for (final p in projects.where((p) => p.status != 'archived'))
                    Builder(
                      builder: (_) {
                        final pt = tasks
                            .where((t) => t.projectId == p.id)
                            .toList();
                        final done = pt
                            .where((t) => t.status == 'completed')
                            .length;
                        final pct = pt.isEmpty
                            ? 0
                            : (done / pt.length * 100).round();
                        return _HBar(
                          label: p.name,
                          value: '$pct% · ${pt.length} tasks',
                          fraction: pct / 100,
                          color: parseHex(p.color),
                        );
                      },
                    ),
                ],
              ),
      ),
      _AnalyticsCard(
        title: 'Team Workload',
        child: workloadEntries.isEmpty
            ? const NoData('No assignments')
            : Column(
                children: [
                  for (final e in workloadEntries.take(8))
                    _HBar(
                      label: e.key.displayName ?? 'Unnamed',
                      leading: AppAvatar(
                        color: parseHex(e.key.color),
                        text: initials(e.key.displayName),
                        size: 20,
                        fontSize: rem(0.6),
                      ),
                      value: '${e.value}',
                      fraction: e.value / workloadEntries.first.value,
                      color: parseHex(e.key.color),
                    ),
                ],
              ),
      ),
      _AnalyticsCard(
        title: 'Summary KPIs',
        child: GridWrap(
          columns: 2,
          gap: 12,
          children: [
            for (final k in kpis) _Kpi(label: k.$1, value: k.$2, color: k.$3),
          ],
        ),
      ),
    ];

    return ListView(
      padding: pagePadding(context),
      children: [
        const ViewHeader(title: 'Analytics'),
        GridWrap(columns: wide ? 2 : 1, gap: 18, children: cards),
      ],
    );
  }
}

/// Web `.analytics-card`: uppercase muted title over the chart.
class _AnalyticsCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _AnalyticsCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: rem(0.88),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.04 * rem(0.88),
              color: c.text2,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Web `.hbar-item`: label + value row over an 8px track.
class _HBar extends StatelessWidget {
  final String label;
  final String value;
  final double fraction;
  final Color color;
  final Widget? leading;
  const _HBar({
    required this.label,
    required this.value,
    required this.fraction,
    required this.color,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 6)],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: rem(0.78),
                    fontWeight: FontWeight.w500,
                    color: c.text2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                value,
                style: TextStyle(fontSize: rem(0.72), color: c.text3),
              ),
            ],
          ),
          const SizedBox(height: 4),
          AppProgress(value: fraction, height: 8, color: color),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Kpi({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: Radii.mdAll,
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: rem(1.4),
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: rem(0.68),
              letterSpacing: 0.04 * rem(0.68),
              color: c.text3,
            ),
          ),
        ],
      ),
    );
  }
}

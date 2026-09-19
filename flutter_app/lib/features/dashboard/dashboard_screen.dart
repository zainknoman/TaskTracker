import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/page_layout.dart';
import '../../widgets/view_header.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceId = ref.watch(activeWorkspaceIdProvider);
    if (workspaceId == null) {
      return const EmptyState(
        icon: Icons.pie_chart,
        message: 'No workspace selected',
      );
    }

    final tasksAsync = ref.watch(tasksProvider(workspaceId));
    final projects =
        ref.watch(projectsProvider(workspaceId)).value ?? const <Project>[];
    final members =
        ref.watch(membersProvider(workspaceId)).value ??
        const <WorkspaceMember>[];

    return tasksAsync.when(
      data: (tasks) =>
          _DashboardBody(tasks: tasks, projects: projects, members: members),
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(e),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final List<Task> tasks;
  final List<Project> projects;
  final List<WorkspaceMember> members;
  const _DashboardBody({
    required this.tasks,
    required this.projects,
    required this.members,
  });

  int _count(String status) => tasks.where((t) => t.status == status).length;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final total = tasks.length;
    final completed = _count('completed');
    final pct = total == 0 ? 0 : (completed / total * 100).round();

    final overdue = tasks.where(isOverdue).length;
    final upcoming =
        tasks
            .where((t) => t.status != 'completed' && t.dueDate != null)
            .toList()
          ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

    final stats = [
      ('Total Tasks', total, Brand.primary, '📋'),
      ('Pending', _count('pending'), Brand.warning, '⏰'),
      ('In Progress', _count('inprogress'), Brand.primary, '▶️'),
      ('Completed', completed, Brand.success, '✅'),
      ('Blocked', _count('blocked'), Brand.danger, '🚫'),
    ];

    // Team workload: open/done per assignee, busiest first (web "Team Workload").
    final workload = <WorkspaceMember, (int, int)>{};
    for (final m in members) {
      final mine = tasks.where((t) => t.assigneeId == m.userId);
      if (mine.isEmpty) continue;
      final done = mine.where((t) => t.status == 'completed').length;
      workload[m] = (mine.length - done, done);
    }
    final workloadEntries = workload.entries.toList()
      ..sort((a, b) => b.value.$1.compareTo(a.value.$1));
    final maxWl = workloadEntries.fold<int>(
      1,
      (m, e) => (e.value.$1 + e.value.$2) > m ? e.value.$1 + e.value.$2 : m,
    );

    return ListView(
      padding: pagePadding(context),
      children: [
        ViewHeader(
          title: 'Dashboard',
          subtitle: DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
        ),
        GridWrap(
          children: [
            for (final s in stats)
              StatCard(label: s.$1, value: s.$2, color: s.$3, emoji: s.$4),
          ],
        ),
        const SizedBox(height: 18),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Overall Task Completion',
                    style: TextStyle(
                      fontSize: rem(0.85),
                      fontWeight: FontWeight.w600,
                      color: c.text2,
                    ),
                  ),
                  Text(
                    '$pct%',
                    style: TextStyle(
                      fontSize: rem(0.85),
                      fontWeight: FontWeight.w700,
                      color: Brand.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AppProgress(value: pct / 100, gradient: true),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Projects Overview',
          child: _ProjectsOverview(
            projects: projects.where((p) => p.status != 'archived').toList(),
            tasks: tasks,
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Upcoming Deadlines',
          trailing: overdue > 0
              ? AppBadge(
                  label: '$overdue overdue',
                  background: Brand.dangerLight,
                  foreground: Brand.danger,
                )
              : null,
          child: upcoming.isEmpty
              ? const NoData('No upcoming deadlines 🎉')
              : Column(
                  children: [
                    for (final (i, t) in upcoming.take(6).indexed)
                      _DeadlineRow(
                        task: t,
                        last:
                            i ==
                            (upcoming.length < 6 ? upcoming.length : 6) - 1,
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        const SectionCard(
          title: 'Recent Activity',
          child: NoData('No activity yet'),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Team Workload',
          child: workloadEntries.isEmpty
              ? const NoData('No team assignments yet')
              : Column(
                  children: [
                    for (final (i, e) in workloadEntries.take(6).indexed)
                      _WorkloadRow(
                        member: e.key,
                        open: e.value.$1,
                        fraction: (e.value.$1 + e.value.$2) / maxWl,
                        last:
                            i ==
                            (workloadEntries.length < 6
                                    ? workloadEntries.length
                                    : 6) -
                                1,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ProjectsOverview extends StatelessWidget {
  final List<Project> projects;
  final List<Task> tasks;
  const _ProjectsOverview({required this.projects, required this.tasks});

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty) return const NoData('No projects');
    final c = context.c;
    return Column(
      children: [
        for (final (i, p) in projects.indexed)
          Builder(
            builder: (context) {
              final pt = tasks.where((t) => t.projectId == p.id).toList();
              final done = pt.where((t) => t.status == 'completed').length;
              final ppct = pt.isEmpty ? 0 : (done / pt.length * 100).round();
              final color = parseHex(p.color);
              return MiniRow(
                last: i == projects.length - 1,
                onTap: () => context.push('/projects/${p.id}'),
                leading: ColorDot(color),
                trailing: Text(
                  '$ppct% · ${pt.length} tasks',
                  style: TextStyle(fontSize: rem(0.72), color: c.text3),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: rem(0.85),
                        fontWeight: FontWeight.w500,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    AppProgress(value: ppct / 100, height: 3, color: color),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class _DeadlineRow extends StatelessWidget {
  final Task task;
  final bool last;
  const _DeadlineRow({required this.task, required this.last});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final days = daysUntil(task.dueDate!);
    final over = days < 0;
    final label = over
        ? '${days.abs()}d overdue'
        : (days == 0 ? 'Today' : '${days}d left');
    final dot = over
        ? const Color(0xFFF87171)
        : (statusMeta[task.status]?.dot ?? Brand.primary);
    return MiniRow(
      last: last,
      onTap: () => context.push('/tasks/${task.id}'),
      leading: ColorDot(dot),
      trailing: Text(
        label,
        style: TextStyle(
          fontSize: rem(0.73),
          color: over ? Brand.danger : c.text3,
        ),
      ),
      child: Text(
        task.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: rem(0.85),
          fontWeight: FontWeight.w500,
          color: c.text,
        ),
      ),
    );
  }
}

class _WorkloadRow extends StatelessWidget {
  final WorkspaceMember member;
  final int open;
  final double fraction;
  final bool last;
  const _WorkloadRow({
    required this.member,
    required this.open,
    required this.fraction,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = parseHex(member.color);
    return MiniRow(
      last: last,
      leading: AppAvatar(
        color: color,
        text: initials(member.displayName),
        size: 28,
        fontSize: rem(0.6),
      ),
      trailing: Text(
        '$open open',
        style: TextStyle(fontSize: rem(0.73), color: c.text3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            member.displayName ?? 'Unnamed',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: rem(0.82),
              fontWeight: FontWeight.w500,
              color: c.text,
            ),
          ),
          const SizedBox(height: 3),
          AppProgress(value: fraction, height: 5, color: color),
        ],
      ),
    );
  }
}

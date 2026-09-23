import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/tokens.dart';
import '../../data/task_transfer_service.dart';
import '../../widgets/app_toast.dart';
import '../../core/ui_helpers.dart';
import '../../data/milestone_repository.dart';
import '../../data/sprint_repository.dart';
import '../../models/milestone.dart';
import '../../models/project.dart';
import '../../models/sprint.dart';
import '../../models/task.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/project_providers.dart';
import '../../providers/task_providers.dart';
import '../../providers/workspace_providers.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/page_layout.dart';
import '../../widgets/priority_badge.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/task_row.dart';
import '../../widgets/view_header.dart';
import '../kanban/kanban_board.dart';
import '../tasks/task_form_sheet.dart';
import 'project_form_sheet.dart';

final _milestoneRepositoryProvider = Provider<MilestoneRepository>(
  (ref) => MilestoneRepository(),
);
final _sprintRepositoryProvider = Provider<SprintRepository>(
  (ref) => SprintRepository(),
);

final _milestonesForProjectProvider =
    FutureProvider.family<List<Milestone>, String>((ref, projectId) {
      return ref.watch(_milestoneRepositoryProvider).listForProject(projectId);
    });

final _sprintsForProjectProvider = FutureProvider.family<List<Sprint>, String>((
  ref,
  projectId,
) {
  return ref.watch(_sprintRepositoryProvider).listForProject(projectId);
});

class ProjectDetailScreen extends ConsumerWidget {
  final String projectId;
  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceId = ref.watch(activeWorkspaceIdProvider);
    if (workspaceId == null) {
      return const SubPage(
        crumbs: ['Projects'],
        body: EmptyState(
          icon: Icons.folder_open,
          message: 'No workspace selected',
        ),
      );
    }

    final projectsAsync = ref.watch(projectsProvider(workspaceId));

    return projectsAsync.when(
      data: (projects) {
        Project? project;
        for (final p in projects) {
          if (p.id == projectId) project = p;
        }
        if (project == null) {
          return const SubPage(
            crumbs: ['Projects'],
            body: EmptyState(
              icon: Icons.error_outline,
              message: 'Project not found',
            ),
          );
        }
        return _ProjectDetailBody(project: project);
      },
      loading: () => const SubPage(crumbs: ['Projects'], body: LoadingView()),
      error: (e, _) => SubPage(crumbs: const ['Projects'], body: ErrorView(e)),
    );
  }
}

class _ProjectDetailBody extends ConsumerStatefulWidget {
  final Project project;
  const _ProjectDetailBody({required this.project});

  @override
  ConsumerState<_ProjectDetailBody> createState() => _ProjectDetailBodyState();
}

class _ProjectDetailBodyState extends ConsumerState<_ProjectDetailBody> {
  int _tab = 0;
  static const _tabs = ['Overview', 'Tasks', 'Kanban', 'Milestones', 'Sprints'];

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final permissions = ref.watch(permissionsProvider);
    final tasks =
        ref.watch(tasksProvider(project.workspaceId)).value ?? const <Task>[];
    final projectTasks = tasks.where((t) => t.projectId == project.id).toList();
    final milestones =
        ref.watch(_milestonesForProjectProvider(project.id)).value ??
        const <Milestone>[];
    final sprints =
        ref.watch(_sprintsForProjectProvider(project.id)).value ??
        const <Sprint>[];

    return SubPage(
      crumbs: ['Projects', project.name],
      body: ListView(
        padding: pagePadding(context),
        children: [
          _Header(
            project: project,
            tasks: projectTasks,
            milestoneCount: milestones.length,
            sprintCount: sprints.length,
            canEdit: permissions.canEdit,
          ),
          const SizedBox(height: 16),
          UnderlineTabs(
            tabs: _tabs,
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 16),
          switch (_tab) {
            0 => _OverviewTab(tasks: projectTasks),
            1 => _TasksTab(
              project: project,
              tasks: projectTasks,
              canEdit: permissions.canEdit,
            ),
            2 => KanbanBoard(tasks: projectTasks),
            3 => _MilestonesTab(projectId: project.id, tasks: tasks),
            _ => _SprintsTab(projectId: project.id, tasks: tasks),
          },
        ],
      ),
    );
  }
}

/// Web `.project-detail-header`.
class _Header extends StatelessWidget {
  final Project project;
  final List<Task> tasks;
  final int milestoneCount;
  final int sprintCount;
  final bool canEdit;
  const _Header({
    required this.project,
    required this.tasks,
    required this.milestoneCount,
    required this.sprintCount,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final p = project;
    final done = tasks.where((t) => t.status == 'completed').length;
    final pct = tasks.isEmpty ? 0 : (done / tasks.length * 100).round();
    final metaStyle = TextStyle(fontSize: rem(0.78), color: c.text3);
    final stats = [
      ('Total', '${tasks.length}', null),
      (
        'In Progress',
        '${tasks.where((t) => t.status == 'inprogress').length}',
        null,
      ),
      ('Completed', '$done', Brand.success),
      (
        'Blocked',
        '${tasks.where((t) => t.status == 'blocked').length}',
        Brand.danger,
      ),
      ('Milestones', '$milestoneCount', Brand.warning),
      ('Sprints', '$sprintCount', null),
    ];

    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 6,
                  constraints: const BoxConstraints(minHeight: 50),
                  decoration: BoxDecoration(
                    color: parseHex(p.color),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          StatusBadge(status: p.status),
                          PriorityBadge(priority: p.priority),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          if (p.client != null && p.client!.isNotEmpty)
                            Text('🏢 ${p.client}', style: metaStyle),
                          if (p.department != null && p.department!.isNotEmpty)
                            Text('📁 ${p.department}', style: metaStyle),
                          if (p.pm != null && p.pm!.isNotEmpty)
                            Text('👤 PM: ${p.pm}', style: metaStyle),
                          if (p.baTeam.isNotEmpty)
                            Text(
                              '📊 BA: ${p.baTeam.join(', ')}',
                              style: metaStyle,
                            ),
                          if (p.startDate != null)
                            Text(
                              '📅 ${fmtDate(p.startDate)} → ${fmtDate(p.endDate)}',
                              style: metaStyle,
                            ),
                          if (p.budget != null)
                            Text('💰 ${p.budget}', style: metaStyle),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (p.description != null && p.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              p.description!,
              style: TextStyle(
                fontSize: rem(0.85),
                color: c.text2,
                height: 1.5,
              ),
            ),
          ],
          if (canEdit) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                AppButton.secondary(
                  'Export JSON',
                  small: true,
                  onPressed: () async {
                    try {
                      await TaskTransferService().exportProject(p, tasks);
                    } catch (e) {
                      if (context.mounted) AppToast.error(context, e.toString());
                    }
                  },
                ),
                const SizedBox(width: 8),
                AppButton.secondary(
                  'Edit',
                  small: true,
                  onPressed: () => ProjectFormSheet.show(context, existing: p),
                ),
                const SizedBox(width: 8),
                AppButton(
                  '+ Task',
                  small: true,
                  onPressed: () =>
                      TaskFormSheet.show(context, initialProjectId: p.id),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.only(top: 14),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.border)),
            ),
            child: GridWrap(
              columns: 3,
              gap: 12,
              children: [
                for (final s in stats)
                  Column(
                    children: [
                      Text(
                        s.$2,
                        style: TextStyle(
                          fontSize: rem(1.5),
                          fontWeight: FontWeight.w800,
                          color: s.$3 ?? c.text,
                        ),
                      ),
                      Text(
                        s.$1.toUpperCase(),
                        style: TextStyle(
                          fontSize: rem(0.68),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.04 * rem(0.68),
                          color: c.text3,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Overall Progress',
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
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final List<Task> tasks;
  const _OverviewTab({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final recent = [...tasks]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final open = tasks.where((t) => t.status != 'completed').take(5).toList();

    Widget row(Task t, Widget trailing, bool last) => MiniRow(
      last: last,
      onTap: () => context.push('/tasks/${t.id}'),
      leading: ColorDot(statusMeta[t.status]?.dot ?? Brand.primary),
      trailing: trailing,
      child: Text(
        t.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: rem(0.85),
          fontWeight: FontWeight.w500,
          color: c.text,
        ),
      ),
    );

    final recentTop = recent.take(5).toList();
    return Column(
      children: [
        SectionCard(
          title: 'Recent Tasks',
          child: recentTop.isEmpty
              ? const NoData('No tasks yet')
              : Column(
                  children: [
                    for (final (i, t) in recentTop.indexed)
                      row(
                        t,
                        StatusBadge(status: t.status),
                        i == recentTop.length - 1,
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Open Tasks',
          child: open.isEmpty
              ? const NoData('All tasks complete! 🎉')
              : Column(
                  children: [
                    for (final (i, t) in open.indexed)
                      row(
                        t,
                        Text(
                          fmtDate(t.dueDate),
                          style: TextStyle(fontSize: rem(0.73), color: c.text3),
                        ),
                        i == open.length - 1,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _TasksTab extends StatelessWidget {
  final Project project;
  final List<Task> tasks;
  final bool canEdit;
  const _TasksTab({
    required this.project,
    required this.tasks,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canEdit)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Align(
              alignment: Alignment.centerRight,
              child: AppButton(
                '+ New Task',
                small: true,
                onPressed: () =>
                    TaskFormSheet.show(context, initialProjectId: project.id),
              ),
            ),
          ),
        TaskTable(
          rows: tasks.isEmpty
              ? [
                  const EmptyState(
                    icon: Icons.check_circle_outline,
                    message: 'No tasks in this project',
                  ),
                ]
              : [
                  for (final (i, t) in tasks.indexed)
                    TaskRow(
                      task: t,
                      last: i == tasks.length - 1,
                      onTap: () => context.push('/tasks/${t.id}'),
                    ),
                ],
        ),
      ],
    );
  }
}

class _MilestonesTab extends ConsumerWidget {
  final String projectId;
  final List<Task> tasks;
  const _MilestonesTab({required this.projectId, required this.tasks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    return ref
        .watch(_milestonesForProjectProvider(projectId))
        .when(
          data: (milestones) {
            if (milestones.isEmpty) return const NoData('No milestones yet');
            return Column(
              children: [
                for (final m in milestones)
                  Builder(
                    builder: (context) {
                      final mt = tasks
                          .where((t) => t.milestoneId == m.id)
                          .toList();
                      final done = mt
                          .where((t) => t.status == 'completed')
                          .length;
                      final (icon, bg) = switch (m.status) {
                        'completed' => ('✅', Brand.successLight),
                        'inprogress' => ('🔄', Brand.primaryLight),
                        _ => ('⏳', Brand.warningLight),
                      };
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          radius: Radii.mdAll,
                          shadow: c.shadowSm,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: bg,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  icon,
                                  style: TextStyle(fontSize: rem(1)),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m.name,
                                      style: TextStyle(
                                        fontSize: rem(0.9),
                                        fontWeight: FontWeight.w600,
                                        color: c.text,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${m.description != null && m.description!.isNotEmpty ? '${m.description} · ' : ''}${fmtDate(m.dueDate)}',
                                      style: TextStyle(
                                        fontSize: rem(0.75),
                                        color: c.text3,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        OutlineChip('$done/${mt.length} tasks'),
                                        StatusBadge(status: m.status),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            );
          },
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(e),
        );
  }
}

class _SprintsTab extends ConsumerWidget {
  final String projectId;
  final List<Task> tasks;
  const _SprintsTab({required this.projectId, required this.tasks});

  static const _colors = {
    'planning': Color(0xFF7C3AED),
    'active': Color(0xFF2563EB),
    'completed': Color(0xFF059669),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    return ref
        .watch(_sprintsForProjectProvider(projectId))
        .when(
          data: (sprints) {
            if (sprints.isEmpty) return const NoData('No sprints yet');
            return Column(
              children: [
                for (final s in sprints)
                  Builder(
                    builder: (context) {
                      final st = tasks
                          .where((t) => t.sprintId == s.id)
                          .toList();
                      final done = st
                          .where((t) => t.status == 'completed')
                          .length;
                      final pct = st.isEmpty
                          ? 0
                          : (done / st.length * 100).round();
                      final color = _colors[s.status] ?? Brand.primary;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          radius: Radii.mdAll,
                          shadow: c.shadowSm,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      s.name,
                                      style: TextStyle(
                                        fontSize: rem(0.9),
                                        fontWeight: FontWeight.w700,
                                        color: c.text,
                                      ),
                                    ),
                                  ),
                                  AppBadge(
                                    label: s.status.isEmpty
                                        ? s.status
                                        : s.status[0].toUpperCase() +
                                              s.status.substring(1),
                                    background: color.withValues(alpha: .13),
                                    foreground: color,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 12,
                                children: [
                                  Text(
                                    '📅 ${fmtDate(s.startDate)} → ${fmtDate(s.endDate)}',
                                    style: TextStyle(
                                      fontSize: rem(0.75),
                                      color: c.text3,
                                    ),
                                  ),
                                  Text(
                                    'Tasks: ${st.length}',
                                    style: TextStyle(
                                      fontSize: rem(0.75),
                                      color: c.text3,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '$done/${st.length} done',
                                    style: TextStyle(
                                      fontSize: rem(0.72),
                                      color: c.text3,
                                    ),
                                  ),
                                  Text(
                                    '$pct%',
                                    style: TextStyle(
                                      fontSize: rem(0.72),
                                      color: c.text3,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              AppProgress(
                                value: pct / 100,
                                height: 5,
                                color: color,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            );
          },
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(e),
        );
  }
}

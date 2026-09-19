import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/tokens.dart';
import '../../core/ui_helpers.dart';
import '../../models/project.dart';
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
import '../../widgets/view_header.dart';
import 'project_form_sheet.dart';

const _projectStatusOptions = [
  ('planning', 'Planning'),
  ('active', 'Active'),
  ('onhold', 'On Hold'),
  ('completed', 'Completed'),
  ('archived', 'Archived'),
];

class ProjectsListScreen extends ConsumerStatefulWidget {
  const ProjectsListScreen({super.key});

  @override
  ConsumerState<ProjectsListScreen> createState() => _ProjectsListScreenState();
}

class _ProjectsListScreenState extends ConsumerState<ProjectsListScreen> {
  int _view = 0; // 0 = grid, 1 = list
  String? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final workspaceId = ref.watch(activeWorkspaceIdProvider);
    final permissions = ref.watch(permissionsProvider);

    if (workspaceId == null) {
      return const EmptyState(
        icon: Icons.folder,
        message: 'No workspace selected',
      );
    }

    final projectsAsync = ref.watch(projectsProvider(workspaceId));
    final tasks = ref.watch(tasksProvider(workspaceId)).value ?? const <Task>[];

    return projectsAsync.when(
      data: (all) {
        final projects = _statusFilter == null
            ? all
            : all.where((p) => p.status == _statusFilter).toList();
        return ListView(
          padding: pagePadding(context),
          children: [
            ViewHeader(
              title: 'Projects',
              subtitle:
                  '${projects.length} project${projects.length == 1 ? '' : 's'}',
              actions: [
                ViewToggle(
                  index: _view,
                  icons: const [Icons.grid_view_rounded, Icons.view_headline],
                  onChanged: (i) => setState(() => _view = i),
                ),
                FilterSelect<String>(
                  value: _statusFilter,
                  allLabel: 'All Status',
                  options: _projectStatusOptions,
                  onChanged: (v) => setState(() => _statusFilter = v),
                ),
                if (permissions.canEdit)
                  AppButton(
                    '+ New Project',
                    onPressed: () => ProjectFormSheet.show(context),
                  ),
              ],
            ),
            if (projects.isEmpty)
              Padding(
                padding: const EdgeInsets.all(48),
                child: Center(
                  child: Text.rich(
                    TextSpan(
                      text: 'No projects yet. Click ',
                      children: [
                        if (permissions.canEdit) ...const [
                          TextSpan(
                            text: '+ New Project',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: ' to get started.'),
                        ] else
                          const TextSpan(text: 'Nothing to show.'),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: rem(0.85),
                      color: context.c.text3,
                    ),
                  ),
                ),
              )
            else if (_view == 0)
              _ProjectGrid(
                projects: projects,
                tasks: tasks,
                canEdit: permissions.canEdit,
              )
            else
              for (final p in projects)
                _ProjectListRow(project: p, tasks: tasks),
          ],
        );
      },
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(e),
    );
  }
}

class _ProjectGrid extends StatelessWidget {
  final List<Project> projects;
  final List<Task> tasks;
  final bool canEdit;
  const _ProjectGrid({
    required this.projects,
    required this.tasks,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return GridWrap(
      columns: wide ? 2 : 1,
      gap: 18,
      children: [
        for (final p in projects)
          _ProjectCard(project: p, tasks: tasks, canEdit: canEdit),
      ],
    );
  }
}

/// Web `.project-card`.
class _ProjectCard extends StatelessWidget {
  final Project project;
  final List<Task> tasks;
  final bool canEdit;
  const _ProjectCard({
    required this.project,
    required this.tasks,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final p = project;
    final color = parseHex(p.color);
    final pt = tasks.where((t) => t.projectId == p.id).toList();
    final done = pt.where((t) => t.status == 'completed').length;
    final blocked = pt.where((t) => t.status == 'blocked').length;
    final pct = pt.isEmpty ? 0 : (done / pt.length * 100).round();
    final metaStyle = TextStyle(fontSize: rem(0.75), color: c.text3);

    return AppCard(
      onTap: () => context.push('/projects/${p.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 4, color: color),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          p.name,
                          style: TextStyle(
                            fontSize: rem(1),
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                            color: c.text,
                          ),
                        ),
                      ),
                    ),
                    if (p.code != null && p.code!.isNotEmpty)
                      OutlineChip(p.code!),
                  ],
                ),
                if (p.description != null && p.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    p.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: rem(0.8),
                      color: c.text2,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (p.department != null && p.department!.isNotEmpty)
                      Text('📁 ${p.department}', style: metaStyle),
                    if (p.pm != null && p.pm!.isNotEmpty)
                      Text('👤 ${p.pm}', style: metaStyle),
                    if (p.endDate != null)
                      Text('📅 ${fmtDate(p.endDate)}', style: metaStyle),
                    if (blocked > 0)
                      Text(
                        '🚫 $blocked',
                        style: metaStyle.copyWith(color: Brand.danger),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$done/${pt.length} complete',
                      style: TextStyle(fontSize: rem(0.73), color: c.text3),
                    ),
                    Text(
                      '$pct%',
                      style: TextStyle(
                        fontSize: rem(0.73),
                        fontWeight: FontWeight.w700,
                        color: c.text3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                AppProgress(value: pct / 100, height: 5, color: color),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: c.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            StatusBadge(status: p.status),
                            PriorityBadge(priority: p.priority),
                          ],
                        ),
                      ),
                      if (canEdit)
                        AppIconButton(
                          Icons.edit_outlined,
                          size: 14,
                          tooltip: 'Edit',
                          color: c.text3,
                          onPressed: () =>
                              ProjectFormSheet.show(context, existing: p),
                        ),
                    ],
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

/// Web `.project-list-row`.
class _ProjectListRow extends StatelessWidget {
  final Project project;
  final List<Task> tasks;
  const _ProjectListRow({required this.project, required this.tasks});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final p = project;
    final pt = tasks.where((t) => t.projectId == p.id).toList();
    final done = pt.where((t) => t.status == 'completed').length;
    final pct = pt.isEmpty ? 0 : (done / pt.length * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        radius: Radii.mdAll,
        shadow: const [],
        onTap: () => context.push('/projects/${p.id}'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            ColorDot(parseHex(p.color), size: 12),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: rem(0.9),
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusBadge(status: p.status),
                      PriorityBadge(priority: p.priority),
                      Text(
                        '${pt.length} tasks · $pct%',
                        style: TextStyle(fontSize: rem(0.78), color: c.text3),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

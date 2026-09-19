import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/tokens.dart';
import '../../core/ui_helpers.dart';
import '../../data/milestone_repository.dart';
import '../../models/milestone.dart';
import '../../models/project.dart';
import '../../models/task.dart';
import '../../providers/project_providers.dart';
import '../../providers/task_providers.dart';
import '../../providers/workspace_providers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/page_layout.dart';
import '../../widgets/view_header.dart';

const double _dayWidth = 28;
const double _rowHeight = 38;
const double _headerHeight = 36;
const double _labelWidth = 150;

final _ganttMilestoneRepositoryProvider = Provider<MilestoneRepository>(
  (ref) => MilestoneRepository(),
);

final _ganttMilestonesProvider = FutureProvider.family<List<Milestone>, String>(
  (ref, projectId) {
    return ref
        .watch(_ganttMilestoneRepositoryProvider)
        .listForProject(projectId);
  },
);

enum _RowKind { project, milestone, task }

class _GanttRowData {
  final _RowKind kind;
  final String label;
  final DateTime start;
  final DateTime end;
  final Color color;
  final String? taskId;
  const _GanttRowData({
    required this.kind,
    required this.label,
    required this.start,
    required this.end,
    required this.color,
    this.taskId,
  });
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

class GanttScreen extends ConsumerStatefulWidget {
  const GanttScreen({super.key});

  @override
  ConsumerState<GanttScreen> createState() => _GanttScreenState();
}

class _GanttScreenState extends ConsumerState<GanttScreen> {
  String? _selectedProjectId; // null = all projects

  @override
  Widget build(BuildContext context) {
    final workspaceId = ref.watch(activeWorkspaceIdProvider);
    if (workspaceId == null) {
      return const SubPage(
        crumbs: ['Gantt Timeline'],
        body: EmptyState(
          icon: Icons.format_align_left,
          message: 'No workspace selected',
        ),
      );
    }

    final projectsAsync = ref.watch(projectsProvider(workspaceId));
    final tasksAsync = ref.watch(tasksProvider(workspaceId));

    return SubPage(
      crumbs: const ['Gantt Timeline'],
      body: projectsAsync.when(
        data: (projects) => tasksAsync.when(
          data: (allTasks) {
            final visible = projects
                .where(
                  (p) =>
                      p.status != 'archived' &&
                      (_selectedProjectId == null ||
                          p.id == _selectedProjectId),
                )
                .toList();
            return ListView(
              padding: pagePadding(context),
              children: [
                ViewHeader(
                  title: 'Gantt Timeline',
                  actions: [
                    FilterSelect<String>(
                      value: _selectedProjectId,
                      allLabel: 'All Projects',
                      options: [for (final p in projects) (p.id, p.name)],
                      onChanged: (v) => setState(() => _selectedProjectId = v),
                    ),
                  ],
                ),
                if (visible.isEmpty ||
                    allTasks
                        .where((t) => visible.any((p) => p.id == t.projectId))
                        .isEmpty)
                  const AppCard(
                    child: EmptyState(
                      icon: Icons.format_align_left,
                      message: 'No tasks to show on the timeline',
                    ),
                  )
                else
                  _GanttChart(projects: visible, tasks: allTasks),
              ],
            );
          },
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(e),
        ),
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(e),
      ),
    );
  }
}

class _GanttChart extends ConsumerWidget {
  final List<Project> projects;
  final List<Task> tasks;
  const _GanttChart({required this.projects, required this.tasks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = <_GanttRowData>[];

    for (final p in projects) {
      final pt = tasks.where((t) => t.projectId == p.id).toList();
      if (pt.isEmpty) continue;
      final milestones =
          ref.watch(_ganttMilestonesProvider(p.id)).value ??
          const <Milestone>[];

      final pStart = _day(
        p.startDate ??
            pt
                .map((t) => t.startDate ?? t.createdAt)
                .reduce((a, b) => a.isBefore(b) ? a : b),
      );
      var pEnd = _day(
        p.endDate ??
            pt
                .map((t) => t.dueDate ?? t.startDate ?? t.createdAt)
                .reduce((a, b) => a.isAfter(b) ? a : b),
      );
      if (pEnd.isBefore(pStart)) pEnd = pStart;
      rows.add(
        _GanttRowData(
          kind: _RowKind.project,
          label: p.name,
          start: pStart,
          end: pEnd,
          color: parseHex(p.color),
        ),
      );

      for (final m in milestones) {
        if (m.dueDate == null) continue;
        rows.add(
          _GanttRowData(
            kind: _RowKind.milestone,
            label: m.name,
            start: _day(m.dueDate!),
            end: _day(m.dueDate!),
            color: statusMeta[m.status]?.dot ?? const Color(0xFFFBBF24),
          ),
        );
      }

      for (final t in pt) {
        final s = _day(t.startDate ?? t.createdAt);
        var e = _day(t.dueDate ?? s);
        if (e.isBefore(s)) e = s;
        rows.add(
          _GanttRowData(
            kind: _RowKind.task,
            label: t.title,
            start: s,
            end: e,
            color: statusMeta[t.status]?.color ?? Brand.primary,
            taskId: t.id,
          ),
        );
      }
    }

    final today = _day(DateTime.now());
    var rangeStart = rows
        .map((r) => r.start)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    var rangeEnd = rows
        .map((r) => r.end)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    if (today.isBefore(rangeStart)) rangeStart = today;
    if (today.isAfter(rangeEnd)) rangeEnd = today;
    rangeStart = rangeStart.subtract(const Duration(days: 3));
    rangeEnd = rangeEnd.add(const Duration(days: 3));

    final totalDays = math.max(rangeEnd.difference(rangeStart).inDays + 1, 14);
    final totalWidth = totalDays * _dayWidth;
    final c = context.c;

    // month segments for the header + column lines
    final months = <(DateTime, int)>[];
    var cursor = rangeStart;
    var i = 0;
    while (i < totalDays) {
      final nextMonth = DateTime(cursor.year, cursor.month + 1, 1);
      final span = math.min(nextMonth.difference(cursor).inDays, totalDays - i);
      months.add((cursor, span));
      i += span;
      cursor = nextMonth;
    }

    final todayOffset =
        today.difference(rangeStart).inDays * _dayWidth + _dayWidth / 2;

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── left labels ──
          Container(
            width: _labelWidth,
            decoration: BoxDecoration(
              color: c.surface2,
              border: Border(right: BorderSide(color: c.border)),
            ),
            child: Column(
              children: [
                Container(
                  height: _headerHeight,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: c.border, width: 2),
                    ),
                  ),
                  child: Text(
                    'TASK / PROJECT',
                    style: TextStyle(
                      fontSize: rem(0.72),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.05 * rem(0.72),
                      color: c.text3,
                    ),
                  ),
                ),
                for (final r in rows) _LabelCell(row: r),
              ],
            ),
          ),
          // ── right timeline ──
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: totalWidth,
                child: Stack(
                  children: [
                    Column(
                      children: [
                        Container(
                          height: _headerHeight,
                          decoration: BoxDecoration(
                            color: c.surface2,
                            border: Border(
                              bottom: BorderSide(color: c.border, width: 2),
                            ),
                          ),
                          child: Row(
                            children: [
                              for (final m in months)
                                Container(
                                  width: m.$2 * _dayWidth,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    border: Border(
                                      right: BorderSide(color: c.border),
                                    ),
                                  ),
                                  child: Text(
                                    m.$2 >= 8
                                        ? DateFormat('MMM yyyy').format(m.$1)
                                        : DateFormat('MMM').format(m.$1),
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: rem(0.72),
                                      fontWeight: FontWeight.w600,
                                      color: c.text3,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        for (final r in rows)
                          _BarCell(
                            row: r,
                            rangeStart: rangeStart,
                            totalWidth: totalWidth,
                          ),
                      ],
                    ),
                    // today line
                    Positioned(
                      left: todayOffset - 1,
                      top: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: Container(
                          width: 2,
                          color: Brand.danger.withValues(alpha: .7),
                        ),
                      ),
                    ),
                    Positioned(
                      left: todayOffset + 4,
                      top: 4,
                      child: IgnorePointer(
                        child: Text(
                          'TODAY',
                          style: TextStyle(
                            fontSize: rem(0.62),
                            fontWeight: FontWeight.w700,
                            color: Brand.danger,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelCell extends StatelessWidget {
  final _GanttRowData row;
  const _LabelCell({required this.row});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (indent, weight, size, color) = switch (row.kind) {
      _RowKind.project => (14.0, FontWeight.w700, rem(0.8), c.text),
      _RowKind.milestone => (24.0, FontWeight.w400, rem(0.78), c.text),
      _RowKind.task => (34.0, FontWeight.w400, rem(0.78), c.text2),
    };
    return InkWell(
      onTap: row.taskId == null
          ? null
          : () => context.push('/tasks/${row.taskId}'),
      child: Container(
        height: _rowHeight,
        padding: EdgeInsets.only(left: indent, right: 8),
        decoration: BoxDecoration(
          color: row.kind == _RowKind.project ? c.surface2 : null,
          border: Border(bottom: BorderSide(color: c.border)),
        ),
        child: Row(
          children: [
            if (row.kind == _RowKind.project) ...[
              ColorDot(row.color, size: 10),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                row.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: size,
                  fontWeight: weight,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarCell extends StatelessWidget {
  final _GanttRowData row;
  final DateTime rangeStart;
  final double totalWidth;
  const _BarCell({
    required this.row,
    required this.rangeStart,
    required this.totalWidth,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final left = row.start.difference(rangeStart).inDays * _dayWidth;
    final width = (row.end.difference(row.start).inDays + 1) * _dayWidth;

    Widget child;
    if (row.kind == _RowKind.milestone) {
      child = Positioned(
        left: left + _dayWidth / 2 - 6,
        top: (_rowHeight - 12) / 2,
        child: Transform.rotate(
          angle: math.pi / 4,
          child: Container(width: 12, height: 12, color: row.color),
        ),
      );
    } else {
      child = Positioned(
        left: left,
        top: (_rowHeight - 18) / 2,
        width: width,
        height: 18,
        child: Opacity(
          opacity: row.kind == _RowKind.task ? .85 : 1,
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: row.color,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              row.label,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontSize: rem(0.68),
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: _rowHeight,
      width: totalWidth,
      decoration: BoxDecoration(
        color: row.kind == _RowKind.project
            ? c.surface2.withValues(alpha: .5)
            : null,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Stack(children: [child]),
    );
  }
}

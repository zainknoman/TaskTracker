import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/tokens.dart';
import '../../core/ui_helpers.dart';
import '../../models/task.dart';
import '../../providers/task_providers.dart';
import '../../providers/workspace_providers.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_form.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/page_layout.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/view_header.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
  }

  List<Task> _tasksOn(List<Task> tasks, DateTime day) => tasks
      .where(
        (t) =>
            t.dueDate != null &&
            t.dueDate!.year == day.year &&
            t.dueDate!.month == day.month &&
            t.dueDate!.day == day.day,
      )
      .toList();

  void _showTasksForDay(BuildContext context, DateTime day, List<Task> tasks) {
    final dayTasks = _tasksOn(tasks, day);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final c = sheetContext.c;
        return SheetScaffold(
          title: DateFormat('EEEE, d MMMM yyyy').format(day),
          body: dayTasks.isEmpty
              ? const NoData('No tasks due this day')
              : Column(
                  children: [
                    for (final (i, task) in dayTasks.indexed)
                      InkWell(
                        onTap: () {
                          Navigator.pop(sheetContext);
                          context.push('/tasks/${task.id}');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            border: i == dayTasks.length - 1
                                ? null
                                : Border(bottom: BorderSide(color: c.border)),
                          ),
                          child: Row(
                            children: [
                              ColorDot(
                                statusMeta[task.status]?.dot ?? Brand.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  task.title,
                                  style: TextStyle(
                                    fontSize: rem(0.85),
                                    fontWeight: FontWeight.w500,
                                    color: c.text,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              StatusBadge(status: task.status),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final workspaceId = ref.watch(activeWorkspaceIdProvider);
    if (workspaceId == null) {
      return const SubPage(
        crumbs: ['Calendar'],
        body: EmptyState(
          icon: Icons.calendar_today,
          message: 'No workspace selected',
        ),
      );
    }

    final tasksAsync = ref.watch(tasksProvider(workspaceId));

    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    final leadingBlanks = firstOfMonth.weekday % 7; // Sunday = 0
    final cellCount = ((leadingBlanks + daysInMonth + 6) ~/ 7) * 7;
    final now = DateTime.now();

    return SubPage(
      crumbs: const ['Calendar'],
      body: tasksAsync.when(
        data: (tasks) => ListView(
          padding: pagePadding(context),
          children: [
            ViewHeader(
              title: 'Calendar',
              actions: [
                AppButton.ghost(
                  '‹ Prev',
                  small: true,
                  onPressed: () => setState(
                    () => _visibleMonth = DateTime(
                      _visibleMonth.year,
                      _visibleMonth.month - 1,
                    ),
                  ),
                ),
                Text(
                  DateFormat.yMMMM().format(_visibleMonth),
                  style: TextStyle(
                    fontSize: rem(1),
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
                AppButton.ghost(
                  'Next ›',
                  small: true,
                  onPressed: () => setState(
                    () => _visibleMonth = DateTime(
                      _visibleMonth.year,
                      _visibleMonth.month + 1,
                    ),
                  ),
                ),
              ],
            ),
            ClipRRect(
              borderRadius: Radii.mdAll,
              child: Container(
                color: c.border,
                child: Column(
                  children: [
                    Row(
                      children: [
                        for (final d in const [
                          'Sun',
                          'Mon',
                          'Tue',
                          'Wed',
                          'Thu',
                          'Fri',
                          'Sat',
                        ])
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.only(
                                right: 1,
                                bottom: 1,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              color: c.surface2,
                              alignment: Alignment.center,
                              child: Text(
                                d.toUpperCase(),
                                style: TextStyle(
                                  fontSize: rem(0.7),
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.05 * rem(0.7),
                                  color: c.text3,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisSpacing: 1,
                            crossAxisSpacing: 1,
                            childAspectRatio: 0.72,
                          ),
                      itemCount: cellCount,
                      itemBuilder: (context, index) {
                        final dayNum = index - leadingBlanks + 1;
                        if (dayNum < 1 || dayNum > daysInMonth) {
                          return Container(color: c.surface2);
                        }
                        final day = DateTime(
                          _visibleMonth.year,
                          _visibleMonth.month,
                          dayNum,
                        );
                        final dayTasks = _tasksOn(tasks, day);
                        final isToday =
                            day.year == now.year &&
                            day.month == now.month &&
                            day.day == now.day;
                        return _DayCell(
                          day: dayNum,
                          isToday: isToday,
                          tasks: dayTasks,
                          onTap: () => _showTasksForDay(context, day, tasks),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(e),
      ),
    );
  }
}

/// Web `.cal-cell`: date, today ring, status-colored task chips (+N more).
class _DayCell extends StatelessWidget {
  final int day;
  final bool isToday;
  final List<Task> tasks;
  final VoidCallback onTap;
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.tasks,
    required this.onTap,
  });

  (Color, Color) _chip(String status) => switch (status) {
    'inprogress' => (Brand.primaryLight, Brand.primary),
    'completed' => (Brand.successLight, Brand.success),
    'blocked' => (Brand.dangerLight, Brand.danger),
    _ => (Brand.warningLight, Brand.warning),
  };

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(3, 5, 3, 3),
        decoration: BoxDecoration(
          color: c.surface,
          border: isToday ? Border.all(color: Brand.primary, width: 2) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: isToday
                  ? const BoxDecoration(
                      color: Brand.primary,
                      shape: BoxShape.circle,
                    )
                  : null,
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: rem(0.75),
                  fontWeight: FontWeight.w700,
                  color: isToday ? Colors.white : c.text3,
                ),
              ),
            ),
            const SizedBox(height: 3),
            for (final t in tasks.take(3))
              Container(
                height: 5,
                margin: const EdgeInsets.only(bottom: 2),
                decoration: BoxDecoration(
                  color: _chip(t.status).$2.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            if (tasks.length > 3)
              Text(
                '+${tasks.length - 3}',
                style: TextStyle(fontSize: rem(0.62), color: c.text3),
              ),
          ],
        ),
      ),
    );
  }
}

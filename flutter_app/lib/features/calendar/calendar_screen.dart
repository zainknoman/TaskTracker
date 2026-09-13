import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/task.dart';
import '../../providers/task_providers.dart';
import '../../providers/workspace_providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_badge.dart';

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

  void _showTasksForDay(BuildContext context, DateTime day, List<Task> tasks) {
    final dayTasks = tasks
        .where((t) =>
            t.dueDate != null &&
            t.dueDate!.year == day.year &&
            t.dueDate!.month == day.month &&
            t.dueDate!.day == day.day)
        .toList();
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(DateFormat.yMMMMd().format(day), style: Theme.of(context).textTheme.titleMedium),
            ),
            if (dayTasks.isEmpty)
              const Padding(padding: EdgeInsets.only(bottom: 24), child: Text('No tasks due this day'))
            else
              for (final task in dayTasks)
                ListTile(
                  title: Text(task.title),
                  trailing: StatusBadge(status: task.status),
                ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workspaceId = ref.watch(activeWorkspaceIdProvider);
    if (workspaceId == null) {
      return const Scaffold(body: EmptyState(icon: Icons.calendar_month_outlined, message: 'No workspace selected'));
    }

    final tasksAsync = ref.watch(tasksProvider(workspaceId));

    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final leadingBlanks = firstOfMonth.weekday % 7; // Sunday = 0

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat.yMMMM().format(_visibleMonth)),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(
                () => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1)),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(
                () => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1)),
          ),
        ],
      ),
      body: tasksAsync.when(
        data: (tasks) {
          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
            itemCount: leadingBlanks + daysInMonth,
            itemBuilder: (context, index) {
              if (index < leadingBlanks) return const SizedBox.shrink();
              final day = DateTime(_visibleMonth.year, _visibleMonth.month, index - leadingBlanks + 1);
              final count = tasks
                  .where((t) =>
                      t.dueDate != null &&
                      t.dueDate!.year == day.year &&
                      t.dueDate!.month == day.month &&
                      t.dueDate!.day == day.day)
                  .length;
              return InkWell(
                onTap: () => _showTasksForDay(context, day, tasks),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${day.day}'),
                      if (count > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

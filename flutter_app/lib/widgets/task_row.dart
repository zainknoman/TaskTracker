import 'package:flutter/material.dart';

import '../core/tokens.dart';
import '../core/ui_helpers.dart';
import '../models/task.dart';
import 'app_badge.dart';
import 'app_card.dart';
import 'priority_badge.dart';
import 'status_badge.dart';

/// One task as a row of the web `.task-table`, reflowed for mobile: title (+ BA), project pill,
/// status/priority badges, due date, tags and progress. Overdue rows get the red left border.
class TaskRow extends StatelessWidget {
  final Task task;
  final String? projectName;
  final Color? projectColor;
  final VoidCallback? onTap;
  final bool last;
  const TaskRow({
    super.key,
    required this.task,
    this.projectName,
    this.projectColor,
    this.onTap,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final overdue = isOverdue(task);
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: last ? BorderSide.none : BorderSide(color: c.border),
            left: overdue
                ? const BorderSide(color: Brand.danger, width: 3)
                : BorderSide.none,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: rem(0.83),
                fontWeight: FontWeight.w500,
                color: c.text,
              ),
            ),
            if (task.ba != null && task.ba!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  task.ba!,
                  style: TextStyle(fontSize: rem(0.72), color: c.text3),
                ),
              ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 6,
              runSpacing: 5,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (projectName != null)
                  ProjectPill(
                    name: projectName!,
                    color: projectColor ?? Brand.primary,
                  ),
                StatusBadge(status: task.status),
                PriorityBadge(priority: task.priority),
                if (task.dueDate != null)
                  Text(
                    'Due ${fmtDate(task.dueDate)}',
                    style: TextStyle(
                      fontSize: rem(0.72),
                      fontWeight: overdue ? FontWeight.w600 : FontWeight.w400,
                      color: overdue ? Brand.danger : c.text3,
                    ),
                  ),
              ],
            ),
            if (task.tags.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 3,
                runSpacing: 3,
                children: [
                  for (final (i, t) in task.tags.indexed) TagChip(t, index: i),
                ],
              ),
            ],
            if (task.progress > 0) ...[
              const SizedBox(height: 8),
              AppProgress(value: task.progress / 100, height: 4),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${task.progress}%',
                  style: TextStyle(fontSize: rem(0.68), color: c.text3),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Web `.table-wrapper` around a list of [TaskRow]s.
class TaskTable extends StatelessWidget {
  final List<Widget> rows;
  const TaskTable({super.key, required this.rows});

  @override
  Widget build(BuildContext context) => AppCard(child: Column(children: rows));
}

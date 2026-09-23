import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/tokens.dart';
import '../../core/ui_helpers.dart';
import '../../data/exceptions.dart';
import '../../data/task_comment_repository.dart';
import '../../data/task_transfer_service.dart';
import '../../models/project.dart';
import '../../models/task.dart';
import '../../models/task_comment.dart';
import '../../providers/auth_providers.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/project_providers.dart';
import '../../providers/task_providers.dart';
import '../../providers/workspace_providers.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_form.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/page_layout.dart';
import '../../widgets/priority_badge.dart';
import '../../widgets/status_badge.dart';
import 'task_form_sheet.dart';

final _taskTransferServiceProvider = Provider<TaskTransferService>((ref) => TaskTransferService());

final _taskCommentRepositoryProvider = Provider<TaskCommentRepository>(
  (ref) => TaskCommentRepository(),
);

final _commentsForTaskProvider =
    FutureProvider.family<List<TaskComment>, String>((ref, taskId) {
      return ref.watch(_taskCommentRepositoryProvider).listForTask(taskId);
    });

class TaskDetailScreen extends ConsumerWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceId = ref.watch(activeWorkspaceIdProvider);
    if (workspaceId == null) {
      return const SubPage(
        crumbs: ['All Tasks'],
        body: EmptyState(
          icon: Icons.assignment_turned_in,
          message: 'No workspace selected',
        ),
      );
    }

    final tasksAsync = ref.watch(tasksProvider(workspaceId));

    return tasksAsync.when(
      data: (tasks) {
        Task? task;
        for (final t in tasks) {
          if (t.id == taskId) task = t;
        }
        if (task == null) {
          return const SubPage(
            crumbs: ['All Tasks'],
            body: EmptyState(
              icon: Icons.error_outline,
              message: 'Task not found',
            ),
          );
        }
        return _TaskDetailBody(task: task);
      },
      loading: () => const SubPage(crumbs: ['All Tasks'], body: LoadingView()),
      error: (e, _) => SubPage(crumbs: const ['All Tasks'], body: ErrorView(e)),
    );
  }
}

class _TaskDetailBody extends ConsumerStatefulWidget {
  final Task task;
  const _TaskDetailBody({required this.task});

  @override
  ConsumerState<_TaskDetailBody> createState() => _TaskDetailBodyState();
}

class _TaskDetailBodyState extends ConsumerState<_TaskDetailBody> {
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _exportTask(Project? project) async {
    try {
      await ref.read(_taskTransferServiceProvider).exportTask(widget.task, project: project);
    } on Exception catch (e) {
      if (mounted) AppToast.error(context, e.toString());
    }
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) AppToast.success(context, '$label copied');
  }

  Future<void> _changeStatus(String status) async {
    try {
      await ref
          .read(taskRepositoryProvider)
          .update(widget.task.copyWith(status: status));
    } on AppException catch (e) {
      if (mounted) AppToast.error(context, e.message);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete task?',
      message: 'This will permanently delete "${widget.task.title}".',
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(taskRepositoryProvider).delete(widget.task.id);
      if (mounted) Navigator.pop(context);
    } on AppException catch (e) {
      if (mounted) AppToast.error(context, e.message);
    }
  }

  Future<void> _postComment() async {
    final body = _commentController.text.trim();
    if (body.isEmpty) return;
    final workspaceId = ref.read(activeWorkspaceIdProvider);
    final userId = ref.read(currentUserProvider)?.id;
    if (workspaceId == null || userId == null) return;
    try {
      final now = DateTime.now();
      await ref
          .read(_taskCommentRepositoryProvider)
          .create(
            TaskComment(
              id: '',
              taskId: widget.task.id,
              workspaceId: workspaceId,
              authorId: userId,
              body: body,
              createdAt: now,
            ),
          );
      _commentController.clear();
      ref.invalidate(_commentsForTaskProvider(widget.task.id));
    } on AppException catch (e) {
      if (mounted) AppToast.error(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final task = widget.task;
    final permissions = ref.watch(permissionsProvider);
    final commentsAsync = ref.watch(_commentsForTaskProvider(task.id));
    final projects =
        ref.watch(projectsProvider(task.workspaceId)).value ??
        const <Project>[];
    Project? project;
    for (final p in projects) {
      if (p.id == task.projectId) project = p;
    }
    final overdue = isOverdue(task);

    Widget field(String label, Widget value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: rem(0.68),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.05 * rem(0.68),
            color: c.text3,
          ),
        ),
        const SizedBox(height: 3),
        value,
      ],
    );
    TextStyle valueStyle([Color? color]) =>
        TextStyle(fontSize: rem(0.85), color: color ?? c.text);

    return SubPage(
      crumbs: ['All Tasks', task.title],
      actions: [
        AppButton.secondary(
          'Export JSON',
          small: true,
          onPressed: () => _exportTask(project),
        ),
        if (permissions.canEdit)
          AppButton.secondary(
            'Edit',
            small: true,
            onPressed: () => TaskFormSheet.show(context, existing: task),
          ),
        if (permissions.canDelete(task.createdBy))
          AppIconButton(
            Icons.delete_outline,
            tooltip: 'Delete',
            danger: true,
            onPressed: _delete,
          ),
      ],
      body: ListView(
        padding: pagePadding(context),
        children: [
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(width: 10),
                    StatusBadge(status: task.status),
                  ],
                ),
                if (project != null) ...[
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ProjectPill(
                      name: '📁 ${project.name}',
                      color: parseHex(project.color),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                GridWrap(
                  columns: 2,
                  gap: 14,
                  children: [
                    field(
                      'Priority',
                      Align(
                        alignment: Alignment.centerLeft,
                        child: PriorityBadge(priority: task.priority),
                      ),
                    ),
                    field(
                      'Status',
                      Align(
                        alignment: Alignment.centerLeft,
                        child: StatusBadge(status: task.status),
                      ),
                    ),
                    field(
                      'Assigned BA',
                      Text(
                        task.ba?.isNotEmpty == true ? task.ba! : '—',
                        style: valueStyle(),
                      ),
                    ),
                    field(
                      'Start Date',
                      Text(fmtDate(task.startDate), style: valueStyle()),
                    ),
                    field(
                      'Due Date',
                      Text(
                        '${fmtDate(task.dueDate)}${overdue ? ' ⚠️' : ''}',
                        style: valueStyle(overdue ? Brand.danger : null),
                      ),
                    ),
                    field(
                      'Estimated Hours',
                      Text(
                        '${task.estimatedHours ?? 0} hrs',
                        style: valueStyle(),
                      ),
                    ),
                    field(
                      'Actual Hours',
                      Text('${task.actualHours ?? 0} hrs', style: valueStyle()),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                field(
                  'Progress — ${task.progress}%',
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: AppProgress(
                      value: task.progress / 100,
                      gradient: true,
                    ),
                  ),
                ),
                if (task.description != null && task.description!.isNotEmpty)
                  _DetailSection(
                    title: 'Description',
                    action: _CopyButton(onPressed: () => _copy(task.description!, 'Description')),
                    child: Text(
                      task.description!,
                      style: TextStyle(
                        fontSize: rem(0.85),
                        color: c.text2,
                        height: 1.6,
                      ),
                    ),
                  ),
                if (task.notes != null && task.notes!.isNotEmpty)
                  _DetailSection(
                    title: 'Notes',
                    action: _CopyButton(onPressed: () => _copy(task.notes!, 'Notes')),
                    child: MarkdownBody(
                      data: task.notes!,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(fontSize: rem(0.85), color: c.text2, height: 1.6),
                        h1: TextStyle(fontSize: rem(1.25), color: c.text, fontWeight: FontWeight.w800),
                        h2: TextStyle(fontSize: rem(1.05), color: c.text, fontWeight: FontWeight.w700),
                        h3: TextStyle(fontSize: rem(0.95), color: c.text, fontWeight: FontWeight.w700),
                        code: TextStyle(fontSize: rem(0.78), color: c.text),
                      ),
                    ),
                  ),
                if (task.tags.isNotEmpty)
                  _DetailSection(
                    title: 'Tags',
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final (i, t) in task.tags.indexed)
                          TagChip(t, index: i),
                      ],
                    ),
                  ),
                if (task.subtasks.isNotEmpty)
                  _DetailSection(
                    title:
                        'Subtasks (${task.subtasks.where((s) => s is Map && s['done'] == true).length}/${task.subtasks.length})',
                    child: Column(
                      children: [
                        for (final s in task.subtasks)
                          _SubtaskRow(
                            title: s is Map ? '${s['title'] ?? ''}' : '$s',
                            done: s is Map && s['done'] == true,
                            onCopy: () => _copy(s is Map ? '${s['title'] ?? ''}' : '$s', 'Subtask'),
                          ),
                      ],
                    ),
                  ),
                if (task.documents.isNotEmpty)
                  _DetailSection(
                    title: 'Reference Documents',
                    child: Column(
                      children: [
                        for (final d in task.documents)
                          _DocRow(
                            title: d is Map
                                ? '${d['title'] ?? d['url'] ?? ''}'
                                : '$d',
                          ),
                      ],
                    ),
                  ),
                if (permissions.canEdit)
                  _DetailSection(
                    title: 'Update Status',
                    child: AppDropdown<String>(
                      label: '',
                      value: task.status,
                      items: [
                        for (final s in taskStatusOptions)
                          DropdownMenuItem(value: s.$1, child: Text(s.$2)),
                      ],
                      onChanged: (v) => v != null ? _changeStatus(v) : null,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Comments',
            child: Column(
              children: [
                commentsAsync.when(
                  data: (comments) => comments.isEmpty
                      ? const NoData('No comments yet')
                      : Column(
                          children: [
                            for (final (i, comment) in comments.indexed)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  border: i == comments.length - 1
                                      ? null
                                      : Border(
                                          bottom: BorderSide(color: c.border),
                                        ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      comment.body,
                                      style: TextStyle(
                                        fontSize: rem(0.85),
                                        color: c.text,
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      DateFormat('d MMM yyyy, HH:mm')
                                          .format(comment.createdAt.toLocal()),
                                      style: TextStyle(
                                        fontSize: rem(0.72),
                                        color: c.text3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                  loading: () => const Padding(
                    padding: EdgeInsets.all(20),
                    child: LoadingView(),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Error: $e'),
                  ),
                ),
                if (permissions.canEdit)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: c.border)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            style: TextStyle(
                              fontSize: rem(0.85),
                              color: c.text,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Add a comment',
                            ),
                            onSubmitted: (_) => _postComment(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AppButton('Post', onPressed: _postComment),
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

/// Web `.detail-section`: uppercase heading followed by a hairline.
class _DetailSection extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;
  const _DetailSection({required this.title, required this.child, this.action});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: rem(0.72),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.05 * rem(0.72),
                  color: c.text3,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(child: Container(height: 1, color: c.border)),
              if (action != null) ...[const SizedBox(width: 8), action!],
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _CopyButton({required this.onPressed});

  @override
  Widget build(BuildContext context) => TextButton(onPressed: onPressed, child: const Text('Copy'));
}

class _SubtaskRow extends StatelessWidget {
  final String title;
  final bool done;
  final VoidCallback onCopy;
  const _SubtaskRow({required this.title, required this.done, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(done ? '✅' : '⬜'),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: rem(0.82),
                color: done ? c.text3 : c.text,
                decoration: done ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          _CopyButton(onPressed: onCopy),
        ],
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  final String title;
  const _DocRow({required this.title});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: Radii.smAll,
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          const Text('📄'),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: rem(0.85), color: Brand.primary),
            ),
          ),
        ],
      ),
    );
  }
}

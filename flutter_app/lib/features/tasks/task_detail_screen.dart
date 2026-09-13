import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/exceptions.dart';
import '../../data/task_comment_repository.dart';
import '../../models/task.dart';
import '../../models/task_comment.dart';
import '../../providers/auth_providers.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/task_providers.dart';
import '../../providers/workspace_providers.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/priority_badge.dart';
import 'task_form_sheet.dart';

final _taskCommentRepositoryProvider = Provider<TaskCommentRepository>((ref) => TaskCommentRepository());

final _commentsForTaskProvider = FutureProvider.family<List<TaskComment>, String>((ref, taskId) {
  return ref.watch(_taskCommentRepositoryProvider).listForTask(taskId);
});

class TaskDetailScreen extends ConsumerWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceId = ref.watch(activeWorkspaceIdProvider);
    if (workspaceId == null) {
      return const Scaffold(body: EmptyState(icon: Icons.task_outlined, message: 'No workspace selected'));
    }

    final tasksAsync = ref.watch(tasksProvider(workspaceId));

    return tasksAsync.when(
      data: (tasks) {
        Task? task;
        for (final t in tasks) {
          if (t.id == taskId) task = t;
        }
        if (task == null) {
          return const Scaffold(body: EmptyState(icon: Icons.error_outline, message: 'Task not found'));
        }
        return _TaskDetailBody(task: task);
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
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

  Future<void> _changeStatus(String status) async {
    try {
      await ref.read(taskRepositoryProvider).update(widget.task.copyWith(status: status));
    } on AppException catch (e) {
      if (mounted) AppToast.error(context, e.message);
    }
  }

  Future<void> _delete() async {
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
      await ref.read(_taskCommentRepositoryProvider).create(TaskComment(
            id: '',
            taskId: widget.task.id,
            workspaceId: workspaceId,
            authorId: userId,
            body: body,
            createdAt: now,
          ));
      _commentController.clear();
      ref.invalidate(_commentsForTaskProvider(widget.task.id));
    } on AppException catch (e) {
      if (mounted) AppToast.error(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final permissions = ref.watch(permissionsProvider);
    final commentsAsync = ref.watch(_commentsForTaskProvider(task.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(task.title),
        actions: [
          if (permissions.canEdit)
            IconButton(icon: const Icon(Icons.edit), onPressed: () => TaskFormSheet.show(context, existing: task)),
          if (permissions.canDelete(task.createdBy))
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [PriorityBadge(priority: task.priority)]),
          const SizedBox(height: 12),
          if (task.description != null) Text(task.description!),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: task.status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: const [
              DropdownMenuItem(value: 'pending', child: Text('Pending')),
              DropdownMenuItem(value: 'inprogress', child: Text('In progress')),
              DropdownMenuItem(value: 'completed', child: Text('Completed')),
              DropdownMenuItem(value: 'blocked', child: Text('Blocked')),
            ],
            onChanged: permissions.canEdit ? (v) => v != null ? _changeStatus(v) : null : null,
          ),
          const SizedBox(height: 24),
          Text('Comments', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          commentsAsync.when(
            data: (comments) => Column(
              children: [
                for (final comment in comments)
                  ListTile(
                    leading: const Icon(Icons.comment_outlined),
                    title: Text(comment.body),
                    subtitle: Text(comment.createdAt.toLocal().toString()),
                  ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
          if (permissions.canEdit) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(hintText: 'Add a comment'),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send), onPressed: _postComment),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

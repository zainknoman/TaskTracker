import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/exceptions.dart';
import '../../models/task.dart';
import '../../providers/project_providers.dart';
import '../../providers/task_providers.dart';
import '../../providers/workspace_providers.dart';
import '../../widgets/app_toast.dart';

class TaskFormSheet extends ConsumerStatefulWidget {
  final Task? existing;
  final String? initialProjectId;
  const TaskFormSheet({super.key, this.existing, this.initialProjectId});

  static Future<void> show(BuildContext context, {Task? existing, String? initialProjectId}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => TaskFormSheet(existing: existing, initialProjectId: initialProjectId),
    );
  }

  @override
  ConsumerState<TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends ConsumerState<TaskFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  String? _projectId;
  String _priority = 'medium';
  String _status = 'pending';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _descriptionController = TextEditingController(text: existing?.description ?? '');
    _projectId = existing?.projectId ?? widget.initialProjectId;
    _priority = existing?.priority ?? 'medium';
    _status = existing?.status ?? 'pending';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final workspaceId = ref.read(activeWorkspaceIdProvider);
    if (workspaceId == null || _projectId == null) return;

    setState(() => _submitting = true);
    try {
      final repository = ref.read(taskRepositoryProvider);
      if (widget.existing != null) {
        await repository.update(widget.existing!.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          priority: _priority,
          status: _status,
        ));
      } else {
        final now = DateTime.now();
        await repository.create(Task(
          id: '',
          workspaceId: workspaceId,
          projectId: _projectId!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          priority: _priority,
          status: _status,
          progress: 0,
          tags: const [],
          documents: const [],
          dependencies: const [],
          subtasks: const [],
          starred: false,
          pinned: false,
          createdBy: '',
          createdAt: now,
          updatedAt: now,
        ));
      }
      if (mounted) Navigator.pop(context);
    } on AppException catch (e) {
      if (mounted) AppToast.error(context, e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspaceId = ref.watch(activeWorkspaceIdProvider);
    final projectsAsync = workspaceId != null ? ref.watch(projectsProvider(workspaceId)) : null;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.existing == null ? 'New task' : 'Edit task',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Title is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                if (projectsAsync != null)
                  projectsAsync.when(
                    data: (projects) => DropdownButtonFormField<String>(
                      initialValue: _projectId,
                      decoration: const InputDecoration(labelText: 'Project'),
                      items: [
                        for (final p in projects) DropdownMenuItem(value: p.id, child: Text(p.name)),
                      ],
                      onChanged: (v) => setState(() => _projectId = v),
                      validator: (v) => v == null ? 'Project is required' : null,
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error loading projects: $e'),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                    DropdownMenuItem(value: 'critical', child: Text('Critical')),
                  ],
                  onChanged: (v) => setState(() => _priority = v ?? _priority),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'in_progress', child: Text('In progress')),
                    DropdownMenuItem(value: 'completed', child: Text('Completed')),
                    DropdownMenuItem(value: 'blocked', child: Text('Blocked')),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? _status),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(widget.existing == null ? 'Create task' : 'Save changes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

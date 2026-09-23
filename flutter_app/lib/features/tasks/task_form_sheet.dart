import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../data/exceptions.dart';
import '../../models/task.dart';
import '../../providers/project_providers.dart';
import '../../providers/task_providers.dart';
import '../../providers/workspace_providers.dart';
import '../../widgets/app_form.dart';
import '../../widgets/app_toast.dart';

class TaskFormSheet extends ConsumerStatefulWidget {
  final Task? existing;
  final String? initialProjectId;
  const TaskFormSheet({super.key, this.existing, this.initialProjectId});

  static Future<void> show(
    BuildContext context, {
    Task? existing,
    String? initialProjectId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          TaskFormSheet(existing: existing, initialProjectId: initialProjectId),
    );
  }

  @override
  ConsumerState<TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends ConsumerState<TaskFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _notesController;
  String? _projectId;
  String _priority = 'medium';
  String _status = 'pending';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    _notesController = TextEditingController(text: existing?.notes ?? '');
    _projectId = existing?.projectId ?? widget.initialProjectId;
    _priority = existing?.priority ?? 'medium';
    _status = existing?.status ?? 'pending';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
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
        await repository.update(
          widget.existing!.copyWith(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            notes: _notesController.text.trim(),
            priority: _priority,
            status: _status,
          ),
        );
      } else {
        final now = DateTime.now();
        await repository.create(
          Task(
            id: '',
            workspaceId: workspaceId,
            projectId: _projectId!,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            notes: _notesController.text.trim(),
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
          ),
        );
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
    final projectsAsync = workspaceId != null
        ? ref.watch(projectsProvider(workspaceId))
        : null;
    final editing = widget.existing != null;

    return SheetScaffold(
      title: editing ? 'Edit Task' : 'New Task',
      footer: sheetActions(
        context,
        submitLabel: editing ? 'Save Changes' : 'Create Task',
        onSubmit: _submitting ? null : _submit,
        loading: _submitting,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: 'Title',
              required: true,
              controller: _titleController,
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Description',
              controller: _descriptionController,
              maxLines: 3,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Notes (plain text or Markdown)',
              controller: _notesController,
              maxLines: 5,
            ),
            if (_notesController.text.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              MarkdownBody(data: _notesController.text.trim()),
            ],
            const SizedBox(height: 14),
            if (projectsAsync != null)
              projectsAsync.when(
                data: (projects) => AppDropdown<String>(
                  label: 'Project',
                  required: true,
                  value: _projectId,
                  items: [
                    for (final p in projects)
                      DropdownMenuItem(value: p.id, child: Text(p.name)),
                  ],
                  onChanged: (v) => setState(() => _projectId = v),
                  validator: (v) => v == null ? 'Project is required' : null,
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error loading projects: $e'),
              ),
            const SizedBox(height: 14),
            AppDropdown<String>(
              label: 'Priority',
              value: _priority,
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Low')),
                DropdownMenuItem(value: 'medium', child: Text('Medium')),
                DropdownMenuItem(value: 'high', child: Text('High')),
                DropdownMenuItem(value: 'critical', child: Text('Critical')),
              ],
              onChanged: (v) => setState(() => _priority = v ?? _priority),
            ),
            const SizedBox(height: 14),
            AppDropdown<String>(
              label: 'Status',
              value: _status,
              items: const [
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(
                  value: 'inprogress',
                  child: Text('In Progress'),
                ),
                DropdownMenuItem(value: 'completed', child: Text('Completed')),
                DropdownMenuItem(value: 'blocked', child: Text('Blocked')),
              ],
              onChanged: (v) => setState(() => _status = v ?? _status),
            ),
          ],
        ),
      ),
    );
  }
}

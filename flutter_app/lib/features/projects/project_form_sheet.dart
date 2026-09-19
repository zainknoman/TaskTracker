import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/exceptions.dart';
import '../../models/project.dart';
import '../../providers/project_providers.dart';
import '../../providers/workspace_providers.dart';
import '../../widgets/app_form.dart';
import '../../widgets/app_toast.dart';

class ProjectFormSheet extends ConsumerStatefulWidget {
  final Project? existing;
  const ProjectFormSheet({super.key, this.existing});

  static Future<void> show(BuildContext context, {Project? existing}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ProjectFormSheet(existing: existing),
    );
  }

  @override
  ConsumerState<ProjectFormSheet> createState() => _ProjectFormSheetState();
}

class _ProjectFormSheetState extends ConsumerState<ProjectFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _clientController;
  String _status = 'planning';
  String _priority = 'medium';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _codeController = TextEditingController(text: existing?.code ?? '');
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    _clientController = TextEditingController(text: existing?.client ?? '');
    _status = existing?.status ?? 'planning';
    _priority = existing?.priority ?? 'medium';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    _clientController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final workspaceId = ref.read(activeWorkspaceIdProvider);
    if (workspaceId == null) return;

    setState(() => _submitting = true);
    try {
      final repository = ref.read(projectRepositoryProvider);
      if (widget.existing != null) {
        await repository.update(
          widget.existing!.copyWith(
            name: _nameController.text.trim(),
            code: _codeController.text.trim(),
            description: _descriptionController.text.trim(),
            client: _clientController.text.trim(),
            status: _status,
            priority: _priority,
          ),
        );
      } else {
        final now = DateTime.now();
        await repository.create(
          Project(
            id: '',
            workspaceId: workspaceId,
            name: _nameController.text.trim(),
            code: _codeController.text.trim(),
            description: _descriptionController.text.trim(),
            status: _status,
            priority: _priority,
            tags: const [],
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
    final editing = widget.existing != null;
    return SheetScaffold(
      title: editing ? 'Edit Project' : 'New Project',
      footer: sheetActions(
        context,
        submitLabel: editing ? 'Save Changes' : 'Create Project',
        onSubmit: _submitting ? null : _submit,
        loading: _submitting,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: 'Project Name',
              required: true,
              controller: _nameController,
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Code',
              controller: _codeController,
              hint: 'e.g. PRJ-01',
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Description',
              controller: _descriptionController,
              maxLines: 3,
            ),
            const SizedBox(height: 14),
            AppTextField(label: 'Client', controller: _clientController),
            const SizedBox(height: 14),
            AppDropdown<String>(
              label: 'Status',
              value: _status,
              items: const [
                DropdownMenuItem(value: 'planning', child: Text('Planning')),
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(value: 'onhold', child: Text('On Hold')),
                DropdownMenuItem(value: 'completed', child: Text('Completed')),
                DropdownMenuItem(value: 'archived', child: Text('Archived')),
              ],
              onChanged: (v) => setState(() => _status = v ?? _status),
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
          ],
        ),
      ),
    );
  }
}

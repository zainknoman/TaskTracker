import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/project_providers.dart';
import '../../providers/task_providers.dart';
import '../../providers/workspace_providers.dart';

class SearchSheet extends ConsumerStatefulWidget {
  const SearchSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const SearchSheet(),
    );
  }

  @override
  ConsumerState<SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends ConsumerState<SearchSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workspaceId = ref.watch(activeWorkspaceIdProvider);
    final tasks = workspaceId != null ? ref.watch(tasksProvider(workspaceId)).value ?? [] : [];
    final projects = workspaceId != null ? ref.watch(projectsProvider(workspaceId)).value ?? [] : [];

    final query = _query.toLowerCase();
    final matchingTasks = query.isEmpty ? [] : tasks.where((t) => t.title.toLowerCase().contains(query)).toList();
    final matchingProjects =
        query.isEmpty ? [] : projects.where((p) => p.name.toLowerCase().contains(query)).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _controller,
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search tasks and projects',
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final project in matchingProjects)
                    ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(project.name),
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/projects/${project.id}');
                      },
                    ),
                  for (final task in matchingTasks)
                    ListTile(
                      leading: const Icon(Icons.task_outlined),
                      title: Text(task.title),
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/tasks/${task.id}');
                      },
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

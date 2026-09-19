import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/tokens.dart';
import '../../core/ui_helpers.dart';
import '../../models/project.dart';
import '../../models/task.dart';
import '../../providers/project_providers.dart';
import '../../providers/task_providers.dart';
import '../../providers/workspace_providers.dart';
import '../../widgets/app_card.dart';

/// Web command-palette / global search: search field over grouped results.
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
    final c = context.c;
    final workspaceId = ref.watch(activeWorkspaceIdProvider);
    final List<Task> tasks = workspaceId != null
        ? ref.watch(tasksProvider(workspaceId)).value ?? []
        : [];
    final List<Project> projects = workspaceId != null
        ? ref.watch(projectsProvider(workspaceId)).value ?? []
        : [];

    final query = _query.toLowerCase();
    final matchingTasks = query.isEmpty
        ? <Task>[]
        : tasks.where((t) => t.title.toLowerCase().contains(query)).toList();
    final matchingProjects = query.isEmpty
        ? <Project>[]
        : projects.where((p) => p.name.toLowerCase().contains(query)).toList();

    Widget group(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: rem(0.68),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.08 * rem(0.68),
          color: c.text3,
        ),
      ),
    );

    Widget item({
      required Widget icon,
      required String label,
      String? sub,
      required VoidCallback onTap,
    }) => InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.surface2,
                borderRadius: Radii.smAll,
              ),
              child: icon,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: rem(0.875),
                      fontWeight: FontWeight.w500,
                      color: c.text,
                    ),
                  ),
                  if (sub != null)
                    Text(
                      sub,
                      style: TextStyle(fontSize: rem(0.72), color: c.text3),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.border)),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 18, color: c.text3),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      style: TextStyle(fontSize: rem(0.95), color: c.text),
                      decoration: const InputDecoration(
                        hintText: 'Search tasks, projects…',
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isCollapsed: true,
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: query.isEmpty
                  ? const NoData('Start typing to search')
                  : (matchingProjects.isEmpty && matchingTasks.isEmpty)
                  ? const NoData('No results found')
                  : ListView(
                      children: [
                        if (matchingProjects.isNotEmpty) group('PROJECTS'),
                        for (final project in matchingProjects)
                          item(
                            icon: ColorDot(parseHex(project.color), size: 10),
                            label: project.name,
                            sub: project.code,
                            onTap: () {
                              Navigator.pop(context);
                              context.push('/projects/${project.id}');
                            },
                          ),
                        if (matchingTasks.isNotEmpty) group('TASKS'),
                        for (final task in matchingTasks)
                          item(
                            icon: Icon(
                              Icons.assignment_turned_in,
                              size: 15,
                              color: c.text3,
                            ),
                            label: task.title,
                            sub: statusMeta[task.status]?.label,
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

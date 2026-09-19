import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens.dart';
import '../../core/ui_helpers.dart';
import '../../data/exceptions.dart';
import '../../models/task.dart';
import '../../models/workspace_member.dart';
import '../../providers/auth_providers.dart';
import '../../providers/member_providers.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/task_providers.dart';
import '../../providers/workspace_providers.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_form.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/page_layout.dart';
import '../../widgets/role_badge.dart';
import '../../widgets/view_header.dart';

class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  Future<void> _editMember(
    BuildContext context,
    WidgetRef ref,
    WorkspaceMember member,
  ) async {
    final nameController = TextEditingController(
      text: member.displayName ?? '',
    );
    final skillsController = TextEditingController(
      text: member.skills.join(', '),
    );

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SheetScaffold(
        title: 'Edit Profile',
        footer: [
          AppButton.secondary(
            'Cancel',
            onPressed: () => Navigator.pop(sheetContext, false),
          ),
          AppButton('Save', onPressed: () => Navigator.pop(sheetContext, true)),
        ],
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(label: 'Display Name', controller: nameController),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Skills (comma separated)',
              controller: skillsController,
            ),
          ],
        ),
      ),
    );

    if (result != true) return;
    try {
      await ref
          .read(memberRepositoryProvider)
          .updateProfile(
            member.copyWith(
              displayName: nameController.text.trim(),
              skills: skillsController.text
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList(),
            ),
          );
      ref.invalidate(membersProvider(member.workspaceId));
    } on AppException catch (e) {
      if (context.mounted) AppToast.error(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceId = ref.watch(activeWorkspaceIdProvider);
    if (workspaceId == null) {
      return const SubPage(
        crumbs: ['Team'],
        body: EmptyState(icon: Icons.groups, message: 'No workspace selected'),
      );
    }

    final membersAsync = ref.watch(membersProvider(workspaceId));
    final permissions = ref.watch(permissionsProvider);
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final tasks = ref.watch(tasksProvider(workspaceId)).value ?? const <Task>[];

    return SubPage(
      crumbs: const ['Team'],
      body: membersAsync.when(
        data: (members) {
          final wide = MediaQuery.sizeOf(context).width >= 700;
          return ListView(
            padding: pagePadding(context),
            children: [
              ViewHeader(
                title: 'Team',
                subtitle:
                    '${members.length} member${members.length == 1 ? '' : 's'}',
              ),
              if (members.isEmpty)
                const AppCard(
                  child: EmptyState(
                    icon: Icons.groups,
                    message: 'No team members yet',
                  ),
                )
              else
                GridWrap(
                  columns: wide ? 2 : 1,
                  gap: 16,
                  children: [
                    for (final member in members)
                      _TeamCard(
                        member: member,
                        tasks: tasks
                            .where((t) => t.assigneeId == member.userId)
                            .toList(),
                        onTap:
                            (permissions.canManageMembers ||
                                member.userId == currentUserId)
                            ? () => _editMember(context, ref, member)
                            : null,
                      ),
                  ],
                ),
            ],
          );
        },
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(e),
      ),
    );
  }
}

/// Web `.team-card`.
class _TeamCard extends StatelessWidget {
  final WorkspaceMember member;
  final List<Task> tasks;
  final VoidCallback? onTap;
  const _TeamCard({required this.member, required this.tasks, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final done = tasks.where((t) => t.status == 'completed').length;
    final open = tasks.length - done;
    final color = parseHex(member.color);

    Widget stat(String value, String label) => Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: rem(1.2),
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
          ),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: rem(0.65),
              letterSpacing: 0.04 * rem(0.65),
              color: c.text3,
            ),
          ),
        ],
      ),
    );

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppAvatar.member(member, emoji: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.displayName ?? 'Unnamed',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: rem(0.95),
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    RoleBadge(role: member.role),
                  ],
                ),
              ),
            ],
          ),
          if (member.skills.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final (i, s) in member.skills.take(4).indexed)
                  TagChip(s, index: i),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.border)),
            ),
            child: Row(
              children: [
                stat('${tasks.length}', 'Tasks'),
                stat('$open', 'Open'),
                stat('$done', 'Done'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Workload',
                style: TextStyle(fontSize: rem(0.72), color: c.text3),
              ),
              Text(
                '${tasks.isEmpty ? 0 : (done / tasks.length * 100).round()}% done',
                style: TextStyle(fontSize: rem(0.72), color: c.text3),
              ),
            ],
          ),
          const SizedBox(height: 3),
          AppProgress(
            value: tasks.isEmpty ? 0 : done / tasks.length,
            height: 5,
            color: color,
          ),
        ],
      ),
    );
  }
}

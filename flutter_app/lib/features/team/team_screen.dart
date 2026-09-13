import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/exceptions.dart';
import '../../models/workspace_member.dart';
import '../../providers/auth_providers.dart';
import '../../providers/member_providers.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/workspace_providers.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/role_badge.dart';

class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  Future<void> _editMember(BuildContext context, WidgetRef ref, WorkspaceMember member) async {
    final nameController = TextEditingController(text: member.displayName ?? '');
    final skillsController = TextEditingController(text: member.skills.join(', '));

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Display name')),
            const SizedBox(height: 12),
            TextField(
              controller: skillsController,
              decoration: const InputDecoration(labelText: 'Skills (comma separated)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save')),
        ],
      ),
    );

    if (result != true) return;
    try {
      await ref.read(memberRepositoryProvider).updateProfile(member.copyWith(
            displayName: nameController.text.trim(),
            skills: skillsController.text
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList(),
          ));
    } on AppException catch (e) {
      if (context.mounted) AppToast.error(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceId = ref.watch(activeWorkspaceIdProvider);
    if (workspaceId == null) {
      return const Scaffold(body: EmptyState(icon: Icons.groups_outlined, message: 'No workspace selected'));
    }

    final membersAsync = ref.watch(membersProvider(workspaceId));
    final permissions = ref.watch(permissionsProvider);
    final currentUserId = ref.watch(currentUserProvider)?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Team')),
      body: membersAsync.when(
        data: (members) {
          if (members.isEmpty) {
            return const EmptyState(icon: Icons.groups_outlined, message: 'No team members yet');
          }
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.1,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              final canEditThis = permissions.canManageMembers || member.userId == currentUserId;
              return Card(
                child: InkWell(
                  onTap: canEditThis ? () => _editMember(context, ref, member) : null,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          child: Text((member.displayName ?? '?').substring(0, 1).toUpperCase()),
                        ),
                        const SizedBox(height: 8),
                        Text(member.displayName ?? 'Unnamed', textAlign: TextAlign.center),
                        const SizedBox(height: 4),
                        RoleBadge(role: member.role),
                        if (member.skills.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 4,
                            children: [for (final s in member.skills.take(3)) Chip(label: Text(s))],
                          ),
                        ],
                      ],
                    ),
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

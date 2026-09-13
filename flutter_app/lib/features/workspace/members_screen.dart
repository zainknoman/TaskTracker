import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/exceptions.dart';
import '../../providers/member_providers.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/workspace_providers.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/role_badge.dart';

class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceId = ref.watch(activeWorkspaceIdProvider);
    final permissions = ref.watch(permissionsProvider);

    if (workspaceId == null) {
      return const Scaffold(body: EmptyState(icon: Icons.group_outlined, message: 'No workspace selected'));
    }

    final membersAsync = ref.watch(membersProvider(workspaceId));

    return Scaffold(
      appBar: AppBar(title: const Text('Team Members')),
      body: membersAsync.when(
        data: (members) {
          if (members.isEmpty) {
            return const EmptyState(icon: Icons.group_outlined, message: 'No members yet');
          }
          return ListView.builder(
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              return ListTile(
                leading: CircleAvatar(child: Text((member.displayName ?? '?').substring(0, 1).toUpperCase())),
                title: Text(member.displayName ?? 'Unnamed'),
                subtitle: Wrap(
                  spacing: 4,
                  children: [for (final skill in member.skills) Chip(label: Text(skill))],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RoleBadge(role: member.role),
                    if (permissions.canManageMembers && member.role != 'owner')
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () async {
                          try {
                            await ref.read(memberRepositoryProvider).remove(member.id);
                          } on AppException catch (e) {
                            if (context.mounted) AppToast.error(context, e.message);
                          }
                        },
                      ),
                  ],
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

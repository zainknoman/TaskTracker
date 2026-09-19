import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens.dart';
import '../../data/exceptions.dart';
import '../../providers/member_providers.dart';
import '../../providers/permissions_provider.dart';
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
import 'invite_sheet.dart';

class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final workspaceId = ref.watch(activeWorkspaceIdProvider);
    final permissions = ref.watch(permissionsProvider);

    if (workspaceId == null) {
      return const SubPage(
        crumbs: ['Members'],
        body: EmptyState(icon: Icons.groups, message: 'No workspace selected'),
      );
    }

    final membersAsync = ref.watch(membersProvider(workspaceId));

    return SubPage(
      crumbs: const ['Members'],
      body: membersAsync.when(
        data: (members) {
          return ListView(
            padding: pagePadding(context),
            children: [
              ViewHeader(
                title: 'Team Members',
                subtitle:
                    '${members.length} member${members.length == 1 ? '' : 's'}',
                actions: [
                  if (permissions.canInvite)
                    AppButton(
                      '+ Invite',
                      onPressed: () => InviteSheet.show(context),
                    ),
                ],
              ),
              if (members.isEmpty)
                const AppCard(
                  child: EmptyState(
                    icon: Icons.groups,
                    message: 'No members yet',
                  ),
                )
              else
                AppCard(
                  child: Column(
                    children: [
                      for (final (i, member) in members.indexed)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: i == members.length - 1
                                ? null
                                : Border(bottom: BorderSide(color: c.border)),
                          ),
                          child: Row(
                            children: [
                              AppAvatar.member(member, size: 36),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      member.displayName ?? 'Unnamed',
                                      style: TextStyle(
                                        fontSize: rem(0.9),
                                        fontWeight: FontWeight.w600,
                                        color: c.text,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: [
                                        RoleBadge(role: member.role),
                                        for (final (j, s)
                                            in member.skills.indexed)
                                          TagChip(s, index: j),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (permissions.canManageMembers &&
                                  member.role != 'owner')
                                AppIconButton(
                                  Icons.person_remove_outlined,
                                  tooltip: 'Remove',
                                  danger: true,
                                  onPressed: () async {
                                    final confirmed = await showConfirmDialog(
                                      context,
                                      title: 'Remove member?',
                                      message:
                                          '${member.displayName ?? 'This member'} will lose access to this workspace.',
                                      confirmLabel: 'Remove',
                                    );
                                    if (!confirmed) return;
                                    try {
                                      await ref
                                          .read(memberRepositoryProvider)
                                          .remove(member.id);
                                      ref.invalidate(
                                        membersProvider(workspaceId),
                                      );
                                    } on AppException catch (e) {
                                      if (context.mounted) {
                                        AppToast.error(context, e.message);
                                      }
                                    }
                                  },
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
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

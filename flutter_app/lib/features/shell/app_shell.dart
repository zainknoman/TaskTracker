import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/tokens.dart';
import '../../providers/notification_providers.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/workspace_providers.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_top_bar.dart';
import '../tasks/task_form_sheet.dart';
import 'app_sidebar.dart';
import 'search_sheet.dart';

const _branchTitles = [
  'Dashboard',
  'Projects',
  'All Tasks',
  'Kanban Board',
  'Notifications',
];

/// App chrome, mirroring the web layout: sidebar (drawer on mobile) + topbar + content.
/// Detail routes (`/projects/:id`, `/tasks/:id`) bring their own topbar with a back button.
class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  final String location;
  const AppShell({
    super.key,
    required this.navigationShell,
    this.location = '',
  });

  bool get _isDetail => Uri.parse(location).pathSegments.length > 1;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(activeWorkspaceProvider);
    final unread = ref.watch(unreadNotificationCountProvider);
    final permissions = ref.watch(permissionsProvider);
    final c = context.c;

    return Scaffold(
      backgroundColor: c.bg,
      drawer: AppSidebar(navigationShell: navigationShell),
      appBar: _isDetail
          ? null
          : AppTopBar(
              crumbs: [
                if (workspace != null) workspace.name,
                _branchTitles[navigationShell.currentIndex],
              ],
              actions: [
                AppIconButton(
                  Icons.search,
                  tooltip: 'Search',
                  onPressed: () => SearchSheet.show(context),
                ),
                _BellButton(
                  count: unread,
                  onPressed: () => navigationShell.goBranch(
                    4,
                    initialLocation: navigationShell.currentIndex == 4,
                  ),
                ),
                if (permissions.canEdit) ...[
                  const SizedBox(width: 4),
                  AppButton(
                    '+ New Task',
                    small: true,
                    onPressed: () => TaskFormSheet.show(context),
                  ),
                ],
              ],
            ),
      body: navigationShell,
    );
  }
}

/// Web `#notificationBell` with `.notification-badge`.
class _BellButton extends StatelessWidget {
  final int count;
  final VoidCallback onPressed;
  const _BellButton({required this.count, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AppIconButton(
          Icons.notifications,
          tooltip: 'Notifications',
          onPressed: onPressed,
        ),
        if (count > 0)
          Positioned(
            top: 2,
            right: 2,
            child: IgnorePointer(
              child: Container(
                constraints: const BoxConstraints(minWidth: 16),
                height: 16,
                padding: const EdgeInsets.symmetric(horizontal: 3),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Brand.danger,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: TextStyle(
                    fontSize: rem(0.6),
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

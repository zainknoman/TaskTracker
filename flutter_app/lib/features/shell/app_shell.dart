import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/notification_providers.dart';
import '../../providers/workspace_providers.dart';
import '../calendar/calendar_screen.dart';
import '../gantt/gantt_screen.dart';
import '../analytics/analytics_screen.dart';
import '../team/team_screen.dart';
import '../workspace/invite_sheet.dart';
import '../workspace/members_screen.dart';
import '../workspace/workspace_switcher_sheet.dart';
import 'search_sheet.dart';

class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const AppShell({super.key, required this.navigationShell});

  void _openMoreSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('Calendar'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalendarScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.view_timeline_outlined),
              title: const Text('Gantt'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GanttScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('Analytics'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AnalyticsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: const Text('Team'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TeamScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.manage_accounts_outlined),
              title: const Text('Members'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MembersScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add_alt_outlined),
              title: const Text('Invite'),
              onTap: () {
                Navigator.pop(sheetContext);
                InviteSheet.show(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeWorkspace = ref.watch(activeWorkspaceProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(activeWorkspace?.name ?? 'TaskFlow Pro'),
        leading: IconButton(
          icon: const Icon(Icons.swap_horiz),
          onPressed: () => WorkspaceSwitcherSheet.show(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () => SearchSheet.show(context)),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () => _openMoreSheet(context)),
        ],
      ),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          const NavigationDestination(icon: Icon(Icons.folder_outlined), label: 'Projects'),
          const NavigationDestination(icon: Icon(Icons.task_outlined), label: 'Tasks'),
          const NavigationDestination(icon: Icon(Icons.view_kanban_outlined), label: 'Kanban'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text('$unreadCount'),
              child: const Icon(Icons.notifications_outlined),
            ),
            label: 'Alerts',
          ),
        ],
      ),
    );
  }
}

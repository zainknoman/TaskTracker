import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/tokens.dart';
import '../../core/ui_helpers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/notification_providers.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/project_providers.dart';
import '../../providers/task_providers.dart';
import '../../providers/workspace_providers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_top_bar.dart';
import '../analytics/analytics_screen.dart';
import '../calendar/calendar_screen.dart';
import '../gantt/gantt_screen.dart';
import '../projects/project_form_sheet.dart';
import '../team/team_screen.dart';
import '../workspace/invite_sheet.dart';
import '../workspace/members_screen.dart';
import '../workspace/workspace_switcher_sheet.dart';

/// The web `.sidebar` as a mobile drawer: dark navy rail with WORKSPACE / PROJECTS / TOOLS
/// sections, a footer with sign-out + theme toggle.
class AppSidebar extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const AppSidebar({super.key, required this.navigationShell});

  void _goBranch(BuildContext context, int index) {
    Navigator.pop(context); // close drawer
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  void _push(BuildContext context, Widget screen) {
    final navigator = Navigator.of(context);
    navigator.pop(); // close drawer
    navigator.push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceId = ref.watch(activeWorkspaceIdProvider);
    final workspace = ref.watch(activeWorkspaceProvider);
    final unread = ref.watch(unreadNotificationCountProvider);
    final permissions = ref.watch(permissionsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final projects = workspaceId != null
        ? ref.watch(projectsProvider(workspaceId)).value ?? []
        : const [];
    final tasks = workspaceId != null
        ? ref.watch(tasksProvider(workspaceId)).value ?? []
        : const [];
    final current = navigationShell.currentIndex;

    return Drawer(
      width: 260,
      backgroundColor: Brand.sidebarBg,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          children: [
            // ── brand (also opens the workspace switcher) ──
            InkWell(
              onTap: () {
                final navigator = Navigator.of(context);
                navigator.pop();
                WorkspaceSwitcherSheet.show(navigator.context);
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Brand.sidebarHover)),
                ),
                child: Row(
                  children: [
                    const BrandLogo(size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              text: 'TaskFlow ',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFFF1F5F9),
                              ),
                              children: const [
                                TextSpan(
                                  text: 'Pro',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                          if (workspace != null)
                            Text(
                              workspace.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: rem(0.7),
                                color: context.c.text3,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.unfold_more,
                      size: 16,
                      color: Brand.sidebarText,
                    ),
                  ],
                ),
              ),
            ),

            // ── nav ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10),
                children: [
                  const _SectionTitle('WORKSPACE'),
                  _NavLink(
                    icon: Icons.pie_chart,
                    label: 'Dashboard',
                    active: current == 0,
                    onTap: () => _goBranch(context, 0),
                  ),
                  _NavLink(
                    icon: Icons.folder,
                    label: 'Projects',
                    badge: projects.length,
                    active: current == 1,
                    onTap: () => _goBranch(context, 1),
                  ),
                  _NavLink(
                    icon: Icons.assignment_turned_in,
                    label: 'All Tasks',
                    badge: tasks.length,
                    active: current == 2,
                    onTap: () => _goBranch(context, 2),
                  ),
                  _NavLink(
                    icon: Icons.grid_view_rounded,
                    label: 'Kanban',
                    active: current == 3,
                    onTap: () => _goBranch(context, 3),
                  ),
                  _NavLink(
                    icon: Icons.calendar_today,
                    label: 'Calendar',
                    onTap: () => _push(context, const CalendarScreen()),
                  ),
                  _NavLink(
                    icon: Icons.format_align_left,
                    label: 'Gantt Timeline',
                    onTap: () => _push(context, const GanttScreen()),
                  ),
                  _NavLink(
                    icon: Icons.bar_chart,
                    label: 'Analytics',
                    onTap: () => _push(context, const AnalyticsScreen()),
                  ),
                  _NavLink(
                    icon: Icons.groups,
                    label: 'Team',
                    onTap: () => _push(context, const TeamScreen()),
                  ),
                  _NavLink(
                    icon: Icons.notifications,
                    label: 'Notifications',
                    badge: unread,
                    badgeColor: const Color(0xFFDC2626),
                    active: current == 4,
                    onTap: () => _goBranch(context, 4),
                  ),
                  _NavLink(
                    icon: Icons.settings,
                    label: 'Members',
                    onTap: () => _push(context, const MembersScreen()),
                  ),

                  // ── projects ──
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 12, 2),
                    child: Row(
                      children: [
                        const Expanded(
                          child: _SectionTitle('PROJECTS', padded: false),
                        ),
                        if (permissions.canEdit)
                          InkWell(
                            borderRadius: BorderRadius.circular(4),
                            onTap: () {
                              final navigator = Navigator.of(context);
                              navigator.pop();
                              ProjectFormSheet.show(navigator.context);
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Icon(
                                Icons.add,
                                size: 17,
                                color: Color(0x66FFFFFF),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  for (final p in projects)
                    _ProjectItem(
                      name: p.name,
                      color: parseHex(p.color),
                      count: tasks.where((t) => t.projectId == p.id).length,
                      onTap: () {
                        final router = GoRouter.of(context);
                        Navigator.pop(context);
                        router.push('/projects/${p.id}');
                      },
                    ),

                  // ── tools ──
                  const SizedBox(height: 6),
                  const _SectionTitle('TOOLS'),
                  _NavLink(
                    icon: Icons.person_add_alt_1,
                    label: 'Invite Member',
                    onTap: () {
                      final navigator = Navigator.of(context);
                      navigator.pop();
                      InviteSheet.show(navigator.context);
                    },
                  ),
                ],
              ),
            ),

            // ── footer ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Brand.sidebarHover)),
              ),
              child: Column(
                children: [
                  _NavLink(
                    icon: Icons.logout,
                    label: 'Sign Out',
                    onTap: () async {
                      final repository = ref.read(authRepositoryProvider);
                      Navigator.pop(context);
                      await repository.signOut();
                    },
                  ),
                  _NavLink(
                    icon: isDark ? Icons.dark_mode : Icons.light_mode,
                    label: isDark ? 'Light Mode' : 'Dark Mode',
                    onTap: () => ref.read(themeModeProvider.notifier).state =
                        isDark ? ThemeMode.light : ThemeMode.dark,
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

class _SectionTitle extends StatelessWidget {
  final String text;
  final bool padded;
  const _SectionTitle(this.text, {this.padded = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padded
          ? const EdgeInsets.fromLTRB(16, 8, 16, 4)
          : EdgeInsets.zero,
      child: Text(
        text,
        style: TextStyle(
          fontSize: rem(0.62),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1 * rem(0.62),
          color: const Color(0x40FFFFFF),
        ),
      ),
    );
  }
}

/// Web `.nav-link` (+ `.active`, `.nav-badge`).
class _NavLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final int? badge;
  final Color badgeColor;
  final VoidCallback onTap;

  const _NavLink({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.badge,
    this.badgeColor = Brand.primary,
  });

  @override
  Widget build(BuildContext context) {
    final fg = active ? Brand.sidebarActiveText : Brand.sidebarText;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 1),
      child: Material(
        color: active ? Brand.sidebarActive : Colors.transparent,
        borderRadius: Radii.smAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.smAll,
          hoverColor: Brand.sidebarHover,
          splashColor: Brand.sidebarHover,
          highlightColor: Brand.sidebarHover,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 17, color: fg),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: rem(0.85), color: fg),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (badge != null && badge! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: Radii.pillAll,
                    ),
                    child: Text(
                      '$badge',
                      style: TextStyle(
                        fontSize: rem(0.68),
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Web `.nav-project-item`.
class _ProjectItem extends StatelessWidget {
  final String name;
  final Color color;
  final int count;
  final VoidCallback onTap;
  const _ProjectItem({
    required this.name,
    required this.color,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 1),
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.smAll,
        hoverColor: Brand.sidebarHover,
        splashColor: Brand.sidebarHover,
        highlightColor: Brand.sidebarHover,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              ColorDot(color, size: 9),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: rem(0.82),
                    color: Brand.sidebarText,
                  ),
                ),
              ),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: rem(0.68),
                  color: const Color(0x4DFFFFFF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

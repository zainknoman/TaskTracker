import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/kanban/kanban_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/projects/project_detail_screen.dart';
import '../features/projects/projects_list_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/tasks/task_detail_screen.dart';
import '../features/tasks/tasks_list_screen.dart';
import 'supabase_config.dart';

class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable() {
    SupabaseConfig.client.auth.onAuthStateChange.listen(
      (_) => notifyListeners(),
    );
  }
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  refreshListenable: _AuthRefreshListenable(),
  redirect: (context, state) {
    final loggedIn = SupabaseConfig.client.auth.currentUser != null;
    final loggingInRoute =
        state.matchedLocation == '/login' || state.matchedLocation == '/signup';

    if (!loggedIn && !loggingInRoute) return '/login';
    if (loggedIn && loggingInRoute) return '/dashboard';
    if (state.matchedLocation == '/') return loggedIn ? '/dashboard' : '/login';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell, location: state.uri.path),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/projects',
              builder: (context, state) => const ProjectsListScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) => ProjectDetailScreen(
                    projectId: state.pathParameters['id']!,
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/tasks',
              builder: (context, state) => const TasksListScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) =>
                      TaskDetailScreen(taskId: state.pathParameters['id']!),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/kanban',
              builder: (context, state) => const KanbanScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/notifications',
              builder: (context, state) => const NotificationsScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);

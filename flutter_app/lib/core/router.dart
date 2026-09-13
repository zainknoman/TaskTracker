import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import 'supabase_config.dart';

class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable() {
    SupabaseConfig.client.auth.onAuthStateChange.listen((_) => notifyListeners());
  }
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  refreshListenable: _AuthRefreshListenable(),
  redirect: (context, state) {
    final loggedIn = SupabaseConfig.client.auth.currentUser != null;
    final loggingInRoute = state.matchedLocation == '/login' || state.matchedLocation == '/signup';

    if (!loggedIn && !loggingInRoute) return '/login';
    if (loggedIn && loggingInRoute) return '/';
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const Scaffold(body: Center(child: Text('Home'))),
    ),
  ],
);

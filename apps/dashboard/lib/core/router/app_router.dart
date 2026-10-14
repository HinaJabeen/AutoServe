// lib/core/router/app_router.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/presentation/login_screen.dart';
import '../../layout/dashboard_shell.dart';
import '../../features/presentation/overview_screen.dart';
import '../../features/inventory/presentation/inventory_grid_screen.dart';
import '../../features/presentation/lead_inbox_screen.dart';
import '../../features/presentation/appointment_scheduler_screen.dart';
import '../../features/presentation/profile_settings_screen.dart';
import '../../features/providers/auth_provider.dart';

class AppRoutes {
  static const login = '/login';
  static const overview = '/overview';
  static const inventory = '/inventory';
  static const leads = '/leads';
  static const schedule = '/schedule';
  static const profile = '/profile';
}

final goRouterProvider = Provider<GoRouter>((ref) {
  // IMPORTANT: do not `ref.watch(authProvider)` here. This Provider body runs
  // once; watching auth state would make Riverpod tear down and recreate the
  // entire GoRouter (and its Navigator/Overlay subtree) on every auth event —
  // including the token-refresh events Supabase fires in the background during
  // any request — which blanks whatever screen/dialog was active and leaves a
  // half-deactivated Element behind (the `_ElementLifecycle.inactive` assertion
  // on next navigation). Auth-driven redirects are re-evaluated via
  // `refreshListenable` below instead, which only re-runs `redirect`, not the
  // whole router.
  return GoRouter(
    initialLocation: AppRoutes.overview,
    refreshListenable: _AuthChangeNotifier(ref),
    redirect: (context, state) {
      final loggedIn = ref.read(authProvider).isAuthenticated;
      final goingToLogin = state.matchedLocation == AppRoutes.login;
      if (!loggedIn && !goingToLogin) return AppRoutes.login;
      if (loggedIn && goingToLogin) return AppRoutes.overview;
      return null;
    },
    routes: [
      // Bare '/' (a fresh tab, a typed base URL, any stray `go('/')`) has no
      // matching GoRoute otherwise — go_router throws GoException instead of
      // falling back to `initialLocation` for a location visited explicitly.
      // `redirect` above still decides login-vs-overview once this resolves.
      GoRoute(
        path: '/',
        redirect: (_, __) => AppRoutes.overview,
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (_, __, child) => DashboardShell(child: child),
        routes: [
          GoRoute(path: AppRoutes.overview, builder: (_, __) => const OverviewScreen()),
          GoRoute(path: AppRoutes.inventory, builder: (_, __) => const InventoryGridScreen()),
          GoRoute(path: AppRoutes.leads, builder: (_, __) => const LeadInboxScreen()),
          GoRoute(path: AppRoutes.schedule, builder: (_, __) => const AppointmentSchedulerScreen()),
          GoRoute(path: AppRoutes.profile, builder: (_, __) => const ProfileSettingsScreen()),
        ],
      ),
    ],
  );
});

class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(this._ref) {
    _ref.listen(authProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;
}
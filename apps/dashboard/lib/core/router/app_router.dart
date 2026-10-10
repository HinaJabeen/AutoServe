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
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: AppRoutes.overview,
    refreshListenable: _AuthChangeNotifier(ref),
    redirect: (context, state) {
      final loggedIn = authState.isAuthenticated;
      final goingToLogin = state.matchedLocation == AppRoutes.login;
      if (!loggedIn && !goingToLogin) return AppRoutes.login;
      if (loggedIn && goingToLogin) return AppRoutes.overview;
      return null;
    },
    routes: [
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
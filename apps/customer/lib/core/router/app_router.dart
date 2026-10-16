// lib/core/router/app_router.dart
//
// Routing for the consumer "Tinder for Cars" app. Every screen except
// /login and /signup sits behind sign-in: `redirect` below reads
// `authProvider` and is re-run (via `refreshListenable`) whenever auth state
// changes, so signing in/out moves the user without any screen having to
// navigate by hand.
//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/compare/presentation/compare_screen.dart';
import '../../features/dealer_application/presentation/become_dealer_screen.dart';
import '../../features/details/presentation/vehicle_detail_screen.dart';
import '../../features/discovery/presentation/swipe_deck_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/saved/presentation/saved_cars_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import 'app_shell.dart';

class AppRoutes {
  static const deck = '/';
  static const splash = '/splash';
  static const login = '/login';
  static const signup = '/signup';
  static const saved = '/saved';
  static const profile = '/profile';
  static const search = '/search';
  static const becomeDealer = '/become-dealer';
  static const compare = '/compare';
  static const vehicleDetail = '/vehicles/:id';

  /// Pre-rename path. Dashboard-printed QR codes encode
  /// `autoserve://vehicle/<id>`, so this must keep resolving.
  static const legacyVehicleDetail = '/vehicle/:id';

  static String vehicleDetailPath(String id) => '/vehicles/$id';

  /// [path] carrying a `?from=` breadcrumb — the location to return to once
  /// signed in (e.g. a `/vehicles/<id>` link opened while signed out).
  static String withFrom(String path, String? from) {
    final target = safeFrom(from);
    if (target == null) return path;
    return Uri(path: path, queryParameters: {'from': target}).toString();
  }

  /// [from] if it's a usable in-app destination, else null. It arrives in the
  /// URL, so it's only honoured when it's a plain in-app path, and never one
  /// of the auth screens themselves (which would loop).
  static String? safeFrom(String? from) {
    if (from == null || !from.startsWith('/') || from.startsWith('//')) {
      return null;
    }
    final path = Uri.tryParse(from)?.path;
    if (path == null || path == deck) return null;
    if (path == splash || path == login || path == signup) return null;
    return from;
  }
}

final goRouterProvider = Provider<GoRouter>((ref) {
  // Deliberately `ref.read`, not `ref.watch`, on authProvider: watching it
  // would rebuild this provider — tearing down the whole GoRouter/Navigator —
  // on every auth event. `refreshListenable` re-runs only `redirect`. (Same
  // reasoning as apps/dashboard's goRouterProvider.)
  return GoRouter(
    initialLocation: AppRoutes.deck,
    refreshListenable: _AuthChangeNotifier(ref),
    redirect: (context, state) {
      final status = ref.read(authProvider).status;
      final location = state.matchedLocation;
      final onSplash = location == AppRoutes.splash;
      final onAuthScreen =
          location == AppRoutes.login || location == AppRoutes.signup;
      // On splash/login/signup the place to return to is whatever `from`
      // they were handed; anywhere else it's the page being visited.
      final from = (onSplash || onAuthScreen)
          ? state.uri.queryParameters['from']
          : state.uri.toString();

      switch (status) {
        case AuthStatus.initial:
          return onSplash ? null : AppRoutes.withFrom(AppRoutes.splash, from);
        case AuthStatus.unauthenticated:
          return onAuthScreen ? null : AppRoutes.withFrom(AppRoutes.login, from);
        case AuthStatus.authenticated:
          if (onSplash || onAuthScreen) {
            return AppRoutes.safeFrom(from) ?? AppRoutes.deck;
          }
          return null;
      }
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, state) =>
            LoginScreen(from: state.uri.queryParameters['from']),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (_, state) =>
            SignupScreen(from: state.uri.queryParameters['from']),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.deck,
              builder: (_, _) => const SwipeDeckScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.saved,
              builder: (_, _) => const SavedCarsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.profile,
              builder: (_, _) => const ProfileScreen(),
            ),
          ]),
        ],
      ),
      GoRoute(
        path: AppRoutes.compare,
        builder: (_, _) => const CompareScreen(),
      ),
      GoRoute(
        path: AppRoutes.becomeDealer,
        builder: (_, _) => const BecomeDealerScreen(),
      ),
      GoRoute(
        path: AppRoutes.search,
        builder: (_, _) => const SearchScreen(),
      ),
      GoRoute(
        path: AppRoutes.vehicleDetail,
        // `extra` carries the CarModel already in hand from the deck so the
        // detail screen can render instantly instead of starting blank — see
        // VehicleDetailScreen's doc comment. It's lost on a page refresh/deep
        // link (web), on the sign-in redirect, or if the deck's internal list
        // changed shape, which is fine: `initialCar` is purely an optimistic
        // first paint, and `vehicleDetailProvider` re-fetches the
        // authoritative data regardless.
        builder: (_, state) => VehicleDetailScreen(
          carId: state.pathParameters['id']!,
          initialCar: state.extra as CarModel?,
        ),
      ),
      GoRoute(
        path: AppRoutes.legacyVehicleDetail,
        redirect: (_, state) =>
            AppRoutes.vehicleDetailPath(state.pathParameters['id']!),
      ),
    ],
  );
});

class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    // Only a change of *status* can change a redirect decision — banner
    // messages and the submitting flag shouldn't re-run it.
    ref.listen(authProvider.select((s) => s.status), (_, _) => notifyListeners());
  }
}

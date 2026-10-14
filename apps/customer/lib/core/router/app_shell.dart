// lib/core/router/app_shell.dart
//
// Bottom-nav chrome for the three tab roots (Explore / Saved / Profile).
// Each tab keeps its own navigator + state via StatefulShellRoute.indexedStack;
// full-screen routes (vehicle detail, search) live outside the shell and
// cover the bar.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';

import '../../features/saved/providers/saved_cars_providers.dart';

// Same phone-width ceiling as the deck, so on desktop the tabs sit under
// the content instead of spreading across the whole window.
const _kNavMaxWidth = 450.0;

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) => navigationShell.goBranch(
        index,
        // Re-tapping the active tab pops it back to its root.
        initialLocation: index == navigationShell.currentIndex,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final savedCount = ref.watch(savedCarsCountProvider);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: p.surface,
          border: Border(top: BorderSide(color: p.border)),
        ),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kNavMaxWidth),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                height: 68,
                indicatorColor: p.accent.withValues(alpha: 0.16),
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
                      color: states.contains(WidgetState.selected) ? p.accent : p.textSecondary,
                    )),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  final selected = states.contains(WidgetState.selected);
                  return AppTextStyles.caption.copyWith(
                    color: selected ? p.accent : p.textSecondary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  );
                }),
              ),
              child: NavigationBar(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: _onTap,
                destinations: [
                  const NavigationDestination(
                    icon: Icon(Icons.explore_outlined),
                    selectedIcon: Icon(Icons.explore_rounded),
                    label: 'Explore',
                  ),
                  NavigationDestination(
                    icon: _SavedIcon(count: savedCount, selected: false),
                    selectedIcon: _SavedIcon(count: savedCount, selected: true),
                    label: 'Saved',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.person_outline_rounded),
                    selectedIcon: Icon(Icons.person_rounded),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedIcon extends StatelessWidget {
  const _SavedIcon({required this.count, required this.selected});
  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Badge(
      isLabelVisible: count > 0,
      backgroundColor: p.accent,
      textColor: p.onAccent,
      label: Text(count > 99 ? '99+' : '$count'),
      child: Icon(selected ? Icons.favorite_rounded : Icons.favorite_border_rounded),
    );
  }
}

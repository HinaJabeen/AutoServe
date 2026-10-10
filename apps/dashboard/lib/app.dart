// apps/dashboard/lib/app.dart
//
// Root widget — wires themeProvider into MaterialApp.router and
// goRouterProvider into the router slot. Merge this into whatever your
// current root widget is; the two provider reads are the only wiring the
// theme switcher and router actually need at the top level.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'package:dashboard/core/router/app_router.dart';
import 'package:dashboard/theme/theme_provider.dart';
import 'package:dashboard/theme/app_theme.dart';

class AutoServeDashboardApp extends ConsumerWidget {
  const AutoServeDashboardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'AutoServe Dashboard',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode == AppThemeMode.dark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }
}

// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dashboard/app.dart';

void main() {
  testWidgets('App boots to the login screen when signed out', (WidgetTester tester) async {
    // AutoServeDashboardApp reads themeProvider/goRouterProvider, both of
    // which need a ProviderScope ancestor to resolve.
    await tester.pumpWidget(
      const ProviderScope(child: AutoServeDashboardApp()),
    );
    await tester.pump();

    // Unauthenticated on cold start → go_router redirects to /login.
    expect(find.text('Sign in'), findsWidgets);
  });
}

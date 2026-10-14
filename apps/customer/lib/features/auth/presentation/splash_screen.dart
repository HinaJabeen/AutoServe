// lib/features/auth/presentation/splash_screen.dart
//
// Shown only while AuthNotifier is restoring a stored session at startup
// (AuthStatus.initial). The router moves on by itself once that resolves.

import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

import 'widgets/auth_scaffold.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandMark(),
            SizedBox(height: AppDimensions.paddingL),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}

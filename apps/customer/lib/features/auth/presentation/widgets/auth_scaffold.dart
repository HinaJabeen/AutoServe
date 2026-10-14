// lib/features/auth/presentation/widgets/auth_scaffold.dart
//
// Shared chrome for the signed-out screens: brand mark, heading, and a
// centered column capped at a phone-ish width so the forms don't stretch
// edge to edge on a laptop browser.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../providers/auth_providers.dart';

const _kAuthMaxWidth = 420.0;

class BrandMark extends StatelessWidget {
  const BrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: p.accent,
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
            boxShadow: [
              BoxShadow(color: p.accentGlow, blurRadius: 18, spreadRadius: 1),
            ],
          ),
          child: Icon(Icons.directions_car_filled_rounded,
              color: p.onAccent, size: AppDimensions.iconSizeM),
        ),
        const SizedBox(width: 12),
        Text(
          'AutoServe',
          style: AppTextStyles.heading2.copyWith(color: p.textPrimary),
        ),
      ],
    );
  }
}

class AuthScaffold extends ConsumerWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;

    // Rate-limit failures arrive as a one-off `snackMessage` rather than the
    // inline banner. Listening here covers both /login and /signup. It fires
    // on each change, and every new attempt resets the field to null first,
    // so hitting the limit twice in a row shows the SnackBar twice.
    ref.listen<String?>(authProvider.select((s) => s.snackMessage),
        (_, message) {
      if (message == null) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 6),
        ));
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kAuthMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: BrandMark(),
                  ),
                  const SizedBox(height: AppDimensions.paddingXL),
                  Text(
                    title,
                    style: AppTextStyles.heading1.copyWith(color: p.textPrimary),
                  ),
                  const SizedBox(height: AppDimensions.paddingS),
                  Text(
                    subtitle,
                    style: AppTextStyles.body.copyWith(color: p.textSecondary),
                  ),
                  const SizedBox(height: AppDimensions.paddingL),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline message above an auth form — red for errors, emerald-tinted for
/// neutral notices ("check your inbox").
class AuthBanner extends StatelessWidget {
  const AuthBanner({super.key, required this.message, this.isError = true});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final foreground = isError ? p.error : p.badgeText;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? p.error.withValues(alpha: 0.1) : p.badgeBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(color: foreground.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.mark_email_read_outlined,
            size: 20,
            color: foreground,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.body.copyWith(color: foreground, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Question? Action" row linking the login and signup screens to each other.
class AuthSwitchLink extends StatelessWidget {
  const AuthSwitchLink({
    super.key,
    required this.question,
    required this.action,
    required this.onTap,
  });

  final String question;
  final String action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          question,
          style: AppTextStyles.body.copyWith(color: context.palette.textSecondary),
        ),
        TextButton(onPressed: onTap, child: Text(action)),
      ],
    );
  }
}

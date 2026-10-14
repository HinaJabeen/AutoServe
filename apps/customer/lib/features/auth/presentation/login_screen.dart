// lib/features/auth/presentation/login_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';

import '../../../core/router/app_router.dart';
import '../../../core/validators.dart';
import '../providers/auth_providers.dart';
import 'widgets/auth_scaffold.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.from});

  /// Where to land after signing in — see `AppRoutes.withFrom`. The router's
  /// redirect does the actual navigation; this is only carried along so the
  /// "Create an account" link doesn't lose it.
  final String? from;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    // On success there's nothing to do here: authProvider flips to
    // authenticated and the router redirects away from /login.
    ref.read(authProvider.notifier).signIn(
          email: _email.text,
          password: _password.text,
        );
  }

  void _goToSignup() {
    ref.read(authProvider.notifier).clearMessages();
    context.go(AppRoutes.withFrom(AppRoutes.signup, widget.from));
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = ref.watch(authProvider.select((s) => s.isSubmitting));
    final error = ref.watch(authProvider.select((s) => s.errorMessage));
    final notice = ref.watch(authProvider.select((s) => s.noticeMessage));
    final p = context.palette;

    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to keep swiping through cars near you.',
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error != null) ...[
                AuthBanner(message: error),
                const SizedBox(height: AppDimensions.paddingM),
              ] else if (notice != null) ...[
                AuthBanner(message: notice, isError: false),
                const SizedBox(height: AppDimensions.paddingM),
              ],
              AppTextField(
                label: 'Email',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.mail_outline_rounded,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: Validators.email,
                enabled: !isSubmitting,
              ),
              const SizedBox(height: AppDimensions.paddingM),
              AppTextField(
                label: 'Password',
                controller: _password,
                obscureText: _obscure,
                prefixIcon: Icons.lock_outline_rounded,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                validator: Validators.passwordRequired,
                onFieldSubmitted: (_) => _submit(),
                enabled: !isSubmitting,
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: p.textTertiary,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              const SizedBox(height: AppDimensions.paddingL),
              AppButton(
                label: 'Sign in',
                isLoading: isSubmitting,
                onPressed: _submit,
              ),
              const SizedBox(height: AppDimensions.paddingM),
              AuthSwitchLink(
                question: 'New to AutoServe?',
                action: 'Create an account',
                onTap: isSubmitting ? null : _goToSignup,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

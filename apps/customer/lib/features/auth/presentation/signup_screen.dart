// lib/features/auth/presentation/signup_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';

import '../../../core/router/app_router.dart';
import '../../../core/validators.dart';
import '../providers/auth_providers.dart';
import 'widgets/auth_scaffold.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key, this.from});

  /// Where to land after signing in — see `AppRoutes.withFrom`.
  final String? from;

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final result = await ref.read(authProvider.notifier).signUp(
          fullName: _fullName.text,
          phone: _phone.text,
          email: _email.text,
          password: _password.text,
        );
    if (!mounted) return;

    // signedIn  → the router redirects off this screen by itself.
    // failed    → authProvider.errorMessage is rendered by the banner below.
    // The project requires email confirmation → hand over to /login, which
    // shows the "check your inbox" notice the notifier just set.
    if (result == SignUpResult.confirmationRequired) {
      context.go(AppRoutes.withFrom(AppRoutes.login, widget.from));
    }
  }

  void _goToLogin() {
    ref.read(authProvider.notifier).clearMessages();
    context.go(AppRoutes.withFrom(AppRoutes.login, widget.from));
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = ref.watch(authProvider.select((s) => s.isSubmitting));
    final error = ref.watch(authProvider.select((s) => s.errorMessage));
    final p = context.palette;

    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'Save the cars you like and book test drives in a tap.',
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error != null) ...[
                AuthBanner(message: error),
                const SizedBox(height: AppDimensions.paddingM),
              ],
              AppTextField(
                label: 'Full name',
                controller: _fullName,
                keyboardType: TextInputType.name,
                prefixIcon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: Validators.fullName,
                enabled: !isSubmitting,
              ),
              const SizedBox(height: AppDimensions.paddingM),
              AppTextField(
                label: 'Phone number',
                controller: _phone,
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone_outlined,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                validator: Validators.phone,
                enabled: !isSubmitting,
              ),
              const SizedBox(height: AppDimensions.paddingM),
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
                hint: 'At least 8 characters, with a letter and a number',
                controller: _password,
                obscureText: _obscure,
                prefixIcon: Icons.lock_outline_rounded,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                validator: Validators.newPassword,
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
                label: 'Create account',
                isLoading: isSubmitting,
                onPressed: _submit,
              ),
              const SizedBox(height: AppDimensions.paddingM),
              AuthSwitchLink(
                question: 'Already have an account?',
                action: 'Sign in',
                onTap: isSubmitting ? null : _goToLogin,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

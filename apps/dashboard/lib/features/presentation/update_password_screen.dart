// apps/dashboard/lib/features/auth/presentation/update_password_screen.dart
//
// Handles two scenarios:
//   1. Password-recovery deep link  (AuthStatus.passwordRecovery)
//   2. First-login forced change    (AuthStatus.requiresPasswordChange)
// After success the router's redirect picks up AuthStatus.authenticated
// and sends the user to their home route automatically.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import 'package:dashboard/features/providers/auth_provider.dart';
import 'package:dashboard/theme/app_palette.dart';

final _loadingProvider = StateProvider<bool>((ref) => false);
final _errorProvider   = StateProvider<String?>((ref) => null);

class UpdatePasswordScreen extends ConsumerStatefulWidget {
  const UpdatePasswordScreen({super.key});
  @override
  ConsumerState<UpdatePasswordScreen> createState() =>
      _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends ConsumerState<UpdatePasswordScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _pwCtrl      = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure      = true;

  @override
  void dispose() { _pwCtrl.dispose(); _confirmCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    ref.read(_loadingProvider.notifier).state = true;
    ref.read(_errorProvider.notifier).state   = null;

    final error = await ref.read(authProvider.notifier)
        .updatePassword(_pwCtrl.text.trim());

    if (!mounted) return;
    ref.read(_loadingProvider.notifier).state = false;

    if (error != null) {
      ref.read(_errorProvider.notifier).state = error;
    }
    // On success: authProvider sets status → authenticated; GoRouter redirects.
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(_loadingProvider);
    final errorMsg  = ref.watch(_errorProvider);
    final authState = ref.watch(authProvider);
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final palette   = context.palette;

    final isForced  = authState.status == AuthStatus.requiresPasswordChange;

    return Scaffold(
      backgroundColor: palette.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                width: 420,
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.white.withOpacity(0.96),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.12)
                        : palette.border,
                    width: 0.8,
                  ),
                  boxShadow: isDark ? [] : [
                    BoxShadow(color: palette.shadowColor.withOpacity(0.10),
                        blurRadius: 40, offset: const Offset(0, 16)),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Icon
                      Center(
                        child: Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(
                            color: palette.accent.withOpacity(0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isForced
                                ? Icons.lock_reset_rounded
                                : Icons.lock_open_rounded,
                            color: palette.accent, size: 26,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Text(
                        isForced ? 'Set a new password' : 'Update your password',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.heading2.copyWith(
                            color: palette.textPrimary, fontSize: 22,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isForced
                            ? 'Your administrator has flagged your account. '
                              'Please set a permanent password to continue.'
                            : 'Enter and confirm your new password below.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption.copyWith(
                            color: palette.textSecondary, fontSize: 12, height: 1.5),
                      ),
                      const SizedBox(height: 28),

                      _label('New password', palette),
                      const SizedBox(height: 6),
                      _PwField(
                        ctrl: _pwCtrl, hint: '••••••••',
                        obscure: _obscure, palette: palette, isDark: isDark,
                        onToggle: () => setState(() => _obscure = !_obscure),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (v.length < 8)
                            return 'Minimum 8 characters';
                          if (!RegExp(r'[A-Z]').hasMatch(v))
                            return 'Include at least one uppercase letter';
                          if (!RegExp(r'[0-9]').hasMatch(v))
                            return 'Include at least one number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      _label('Confirm new password', palette),
                      const SizedBox(height: 6),
                      _PwField(
                        ctrl: _confirmCtrl, hint: '••••••••',
                        obscure: _obscure, palette: palette, isDark: isDark,
                        validator: (v) => v != _pwCtrl.text
                            ? 'Passwords do not match' : null,
                      ),

                      if (errorMsg != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: palette.error.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                                color: palette.error.withOpacity(0.30)),
                          ),
                          child: Text(errorMsg,
                              style: AppTextStyles.caption.copyWith(
                                  color: palette.error, fontSize: 11)),
                        ),
                      ],

                      const SizedBox(height: 22),
                      SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: palette.accent,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                palette.accent.withOpacity(0.5),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(3)),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 1.5, color: Colors.white))
                              : Text('Update password',
                                  style: AppTextStyles.body.copyWith(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text, AppPalette palette) => Text(text,
      style: AppTextStyles.caption.copyWith(
          color: palette.textSecondary,
          fontSize: 11, fontWeight: FontWeight.w500));
}

class _PwField extends StatelessWidget {
  const _PwField({
    required this.ctrl, required this.hint, required this.obscure,
    required this.palette, required this.isDark,
    this.onToggle, this.validator,
  });
  final TextEditingController ctrl;
  final String hint;
  final bool obscure, isDark;
  final AppPalette palette;
  final VoidCallback? onToggle;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: ctrl,
    obscureText: obscure,
    validator: validator,
    style: AppTextStyles.body.copyWith(color: palette.textPrimary, fontSize: 13),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.body.copyWith(
          color: palette.textTertiary, fontSize: 13),
      filled: true,
      fillColor: isDark
          ? Colors.white.withOpacity(0.05)
          : Colors.grey.shade50,
      suffixIcon: onToggle != null
          ? GestureDetector(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 16, color: palette.textTertiary),
              ))
          : null,
      suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: BorderSide(color: palette.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: BorderSide(color: palette.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: BorderSide(color: palette.accent, width: 1.4)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: BorderSide(color: palette.error.withOpacity(0.6))),
    ),
  );
}

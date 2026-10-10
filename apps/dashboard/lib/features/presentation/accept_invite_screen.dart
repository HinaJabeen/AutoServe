// apps/dashboard/lib/features/auth/presentation/accept_invite_screen.dart
//
// Reached via the Supabase invite email deep link, which signs the person
// into a temporary session automatically. This screen's only job is to have
// them set a permanent password — the router's redirect (via refreshListenable
// on authProvider) picks up the newly-resolved role and sends them on from
// here, no manual navigation needed.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared/shared.dart';

import 'package:dashboard/features/providers/auth_provider.dart';

class AcceptInviteScreen extends ConsumerStatefulWidget {
  const AcceptInviteScreen({super.key});

  @override
  ConsumerState<AcceptInviteScreen> createState() => _AcceptInviteScreenState();
}

class _AcceptInviteScreenState extends ConsumerState<AcceptInviteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final hasSession = Supabase.instance.client.auth.currentSession != null;
    if (!hasSession) {
      setState(() {
        _errorMessage = 'This invite link has expired or was already used. Ask for a new invite.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordCtrl.text),
      );
      if (!mounted) return;
      // Resolves role from the now-permanent session; the router's
      // refreshListenable picks up the state change and redirects.
      await ref.read(authProvider.notifier).refreshSession();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.0,
                colors: [
                  const Color(0xFF0A0A0A).withOpacity(0.10),
                  const Color(0xFF0A0A0A).withOpacity(0.82),
                ],
              ),
            ),
          ),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  width: 400,
                  padding: const EdgeInsets.fromLTRB(40, 40, 40, 36),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: Colors.white.withOpacity(0.12), width: 0.8),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Welcome to AutoServe',
                          style: AppTextStyles.heading2.copyWith(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Set a permanent password to finish setting up your account.',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white38,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),

                        Text(
                          'New password',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white.withOpacity(0.32),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _passwordField(
                          _passwordCtrl,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (v.length < 6) return 'Minimum 6 characters';
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),
                        Text(
                          'Confirm password',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white.withOpacity(0.32),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _passwordField(
                          _confirmCtrl,
                          validator: (v) {
                            if (v != _passwordCtrl.text) return 'Passwords do not match';
                            return null;
                          },
                        ),

                        if (_errorMessage != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: AppColors.error.withOpacity(0.22)),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.error.withOpacity(0.85),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 22),
                        SizedBox(
                          height: 42,
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(3),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(3),
                              onTap: _submitting ? null : _submit,
                              child: Ink(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.09),
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                                ),
                                child: Center(
                                  child: _submitting
                                      ? SizedBox(
                                          width: 15,
                                          height: 15,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 1.5,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              Colors.white.withOpacity(0.35),
                                            ),
                                          ),
                                        )
                                      : Text(
                                          'Activate account',
                                          style: AppTextStyles.body.copyWith(
                                            color: Colors.white.withOpacity(0.80),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _passwordField(
    TextEditingController controller, {
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: _obscure,
      validator: validator,
      style: AppTextStyles.body.copyWith(color: Colors.white.withOpacity(0.85), fontSize: 13),
      decoration: InputDecoration(
        hintText: '••••••••',
        hintStyle: AppTextStyles.body.copyWith(color: Colors.white.withOpacity(0.14), fontSize: 13),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () => setState(() => _obscure = !_obscure),
            child: Icon(
              _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 15,
              color: Colors.white.withOpacity(0.20),
            ),
          ),
        ),
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.30)),
        ),
      ),
    );
  }
}

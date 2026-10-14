// apps/dashboard/lib/features/auth/presentation/forgot_password_screen.dart
//
// Kept visually consistent with the login screen's dark glass card, but
// without the full ambient/parallax system — this is a quick utility stop,
// not the branded entry point. Drop in the orb/parallax layers from
// login_screen.dart here too if you want full parity.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared/shared.dart';
import 'package:go_router/go_router.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

enum _SendStatus { idle, sending, sent, error }

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  _SendStatus _status = _SendStatus.idle;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _status = _SendStatus.sending;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _emailCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _status = _SendStatus.sent);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _SendStatus.error;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = _SendStatus.error;
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
          CustomPaint(painter: _DotGridPainter()),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.0,
                colors: [
                  const Color(0xFF0A0A0A).withValues(alpha: 0.10),
                  const Color(0xFF0A0A0A).withValues(alpha: 0.82),
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
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.8),
                  ),
                  child: _status == _SendStatus.sent ? _buildSentState() : _buildFormState(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormState() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Reset your password',
            style: AppTextStyles.heading2.copyWith(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "We'll send a reset link to your email.",
            style: AppTextStyles.caption.copyWith(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 24),

          Text(
            'Email address',
            style: AppTextStyles.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.32),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: AppTextStyles.body.copyWith(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
            decoration: InputDecoration(
              hintText: 'you@dealership.com',
              hintStyle: AppTextStyles.body.copyWith(color: Colors.white.withValues(alpha: 0.14), fontSize: 13),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(3),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(3),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(3),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.30)),
              ),
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.22)),
              ),
              child: Text(
                _errorMessage!,
                style: AppTextStyles.caption.copyWith(color: AppColors.error.withValues(alpha: 0.85), fontSize: 11),
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
                onTap: _status == _SendStatus.sending ? null : _submit,
                child: Ink(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                  ),
                  child: Center(
                    child: _status == _SendStatus.sending
                        ? SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withValues(alpha: 0.35)),
                            ),
                          )
                        : Text(
                            'Send reset link',
                            style: AppTextStyles.body.copyWith(
                              color: Colors.white.withValues(alpha: 0.80),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),
          Center(
            child: GestureDetector(
              onTap: () => context.go('/login'),
              child: Text(
                'Back to sign in',
                style: AppTextStyles.caption.copyWith(color: Colors.white.withValues(alpha: 0.30), fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.mark_email_read_outlined, color: Colors.white.withValues(alpha: 0.6), size: 32),
        const SizedBox(height: 16),
        Text(
          'Check your email',
          style: AppTextStyles.heading2.copyWith(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'If an account exists for ${_emailCtrl.text.trim()}, a reset link is on its way.',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(color: Colors.white38, fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 22),
        TextButton(
          onPressed: () => context.go('/login'),
          child: Text('Back to sign in', style: AppTextStyles.body.copyWith(color: Colors.white70)),
        ),
      ],
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.022);
    const spacing = 36.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 0.8, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

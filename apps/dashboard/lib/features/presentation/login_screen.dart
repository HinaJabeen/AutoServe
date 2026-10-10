// apps/dashboard/lib/features/auth/presentation/login_screen.dart

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
//for login only
import 'package:go_router/go_router.dart';

import 'package:dashboard/features/providers/auth_provider.dart';

// ---------------------------------------------------------------------------
// Brand data
// ---------------------------------------------------------------------------

class _Brand {
  const _Brand({
    required this.name,
    required this.tagline,
    required this.assetPath,
  });
  final String name;
  final String tagline;
  final String assetPath;
}

const _brands = [
  _Brand(
    name: 'MERCEDES-BENZ',
    tagline: 'The best or nothing.',
    assetPath: 'assets/mercedes-logo.png',
  ),
  _Brand(
    name: 'BMW',
    tagline: 'Sheer driving pleasure.',
    assetPath: 'assets/BMW.png',
  ),
  _Brand(
    name: 'AUDI',
    tagline: 'Vorsprung durch Technik.',
    assetPath: 'assets/audi-logo.png',
  ),
  _Brand(
    name: 'PORSCHE',
    tagline: 'There is no substitute.',
    assetPath: 'assets/porshe-logo.png',
  ),
  _Brand(
    name: 'TOYOTA',
    tagline: "Let's go places.",
    assetPath: 'assets/TOYOTA.png',
  ),
];

// ---------------------------------------------------------------------------
// Ambient design tokens — the same darkened midnight-cyan / cobalt palette
// used across the AutoServe dashboard, kept subtle here so it reads as
// instrument-panel lighting rather than a decoration.
// ---------------------------------------------------------------------------

class _Ambient {
  static const cyan = Color(0xFF0090B8);
  static const cyanDeep = Color(0xFF005F73);
  static const cobalt = Color(0xFF0038FF);
}

// ---------------------------------------------------------------------------
// Root screen
// ---------------------------------------------------------------------------

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  int _brandIndex = 0;

  // Drives the brand cross-fade (logo + tagline + strip), exactly as before.
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;

  // Runs forever — every drifting orb, breathing logo, and floating card in
  // this screen reads its motion off a single point on this cycle so the
  // whole scene stays in phase, like it's lit by one shared light rig.
  late final AnimationController _ambientController;

  // Normalized pointer position in [-1, 1] on each axis. Feeds the parallax
  // tilt on the logo and the card, so the whole composition responds to the
  // viewer like an instrument cluster rather than a flat page. Defaults to
  // dead-center on touch devices, where the idle drift alone still carries
  // the "floating in space" feel.
  final ValueNotifier<Offset> _pointer = ValueNotifier<Offset>(Offset.zero);

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..value = 1.0;

    _fadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    _scheduleCycle();
  }

  void _scheduleCycle() {
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      _fadeController.reverse().then((_) {
        if (!mounted) return;
        setState(() => _brandIndex = (_brandIndex + 1) % _brands.length);
        _fadeController.forward().then((_) => _scheduleCycle());
      });
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _ambientController.dispose();
    _pointer.dispose();
    super.dispose();
  }

  void _handlePointer(PointerEvent event, BoxConstraints constraints) {
    final dx = (event.localPosition.dx / constraints.maxWidth) * 2 - 1;
    final dy = (event.localPosition.dy / constraints.maxHeight) * 2 - 1;
    _pointer.value = Offset(dx.clamp(-1.0, 1.0), dy.clamp(-1.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final brand = _brands[_brandIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return MouseRegion(
            onHover: (event) => _handlePointer(event, constraints),
            onExit: (_) => _pointer.value = Offset.zero,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Layer 0 — drifting ambient light sources ──────────────
                _AmbientOrbLayer(controller: _ambientController),

                // ── Layer 1 — dot grid texture, gentle depth parallax ─────
                _ParallaxDotGrid(pointer: _pointer),

                // ── Layer 2 — full-bleed brand logo, breathing + tilting ──
                FadeTransition(
                  opacity: _fadeAnim,
                  child: _BrandLogoBackdrop(
                    brand: brand,
                    pointer: _pointer,
                    drift: _ambientController,
                  ),
                ),

                // ── Layer 3 — edge vignette, frames the composition ───────
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.0,
                      colors: [
                        Colors.black.withOpacity(0.10),
                        Colors.black.withOpacity(0.88),
                      ],
                    ),
                  ),
                ),

                // ── Layer 4 — the login card, floating in 3D space ────────
                Center(
                  child: _FloatingCardStage(
                    pointer: _pointer,
                    drift: _ambientController,
                    child: _LoginCard(brand: brand, fadeAnim: _fadeAnim),
                  ),
                ),

                // ── Layer 5 — bottom brand strip ──────────────────────────
                Positioned(
                  bottom: 28,
                  left: 0,
                  right: 0,
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          brand.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withOpacity(0.14),
                            letterSpacing: 5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Progress dots — active dot picks up a faint LED glow.
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_brands.length, (i) {
                            final active = i == _brandIndex;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOut,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: active ? 18 : 4,
                              height: 2,
                              decoration: BoxDecoration(
                                color: active
                                    ? _Ambient.cyan.withOpacity(0.65)
                                    : Colors.white.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: active
                                    ? [
                                        BoxShadow(
                                          color: _Ambient.cyan.withOpacity(0.55),
                                          blurRadius: 8,
                                          spreadRadius: 0.5,
                                        ),
                                      ]
                                    : null,
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ambient orb layer — three soft, colored light sources drifting on slow,
// independent Lissajous paths. This is the "ambient lighting" for the whole
// scene; the logo, dot grid, and glass card all sit on top of it.
// ---------------------------------------------------------------------------

class _AmbientOrbLayer extends StatelessWidget {
  const _AmbientOrbLayer({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return CustomPaint(painter: _AmbientLightPainter(controller.value));
      },
    );
  }
}

class _AmbientLightPainter extends CustomPainter {
  _AmbientLightPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final angle = t * 2 * math.pi;

    _drawOrb(
      canvas,
      center: Offset(
        size.width * (0.30 + 0.10 * math.sin(angle * 0.7)),
        size.height * (0.24 + 0.08 * math.cos(angle * 0.55)),
      ),
      radius: size.shortestSide * 0.50,
      color: _Ambient.cyan.withOpacity(0.07),
    );

    _drawOrb(
      canvas,
      center: Offset(
        size.width * (0.72 + 0.09 * math.cos(angle * 0.5 + 1.2)),
        size.height * (0.70 + 0.10 * math.sin(angle * 0.65 + 0.6)),
      ),
      radius: size.shortestSide * 0.55,
      color: _Ambient.cobalt.withOpacity(0.05),
    );

    _drawOrb(
      canvas,
      center: Offset(
        size.width * (0.55 + 0.12 * math.sin(angle * 0.4 + 2.4)),
        size.height * (0.42 + 0.07 * math.cos(angle * 0.85)),
      ),
      radius: size.shortestSide * 0.32,
      color: _Ambient.cyanDeep.withOpacity(0.05),
    );
  }

  void _drawOrb(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
  }) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withOpacity(0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _AmbientLightPainter oldDelegate) =>
      oldDelegate.t != t;
}

// ---------------------------------------------------------------------------
// Dot grid — unchanged texture, now nudged a few pixels against the pointer
// so it reads as the furthest-back layer in the stack.
// ---------------------------------------------------------------------------

class _ParallaxDotGrid extends StatelessWidget {
  const _ParallaxDotGrid({required this.pointer});
  final ValueNotifier<Offset> pointer;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Offset>(
      valueListenable: pointer,
      builder: (context, p, _) {
        return Transform.translate(
          offset: Offset(p.dx * -6, p.dy * -6),
          child: CustomPaint(painter: _DotGridPainter()),
        );
      },
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.022);
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

// ---------------------------------------------------------------------------
// Full-bleed brand logo — large, desaturated, blurred backdrop. Now breathes
// gently on the ambient cycle and tilts a few degrees toward the pointer, so
// it sits in the scene like a HUD projection rather than a flat sticker.
// ---------------------------------------------------------------------------

class _BrandLogoBackdrop extends StatelessWidget {
  const _BrandLogoBackdrop({
    required this.brand,
    required this.pointer,
    required this.drift,
  });
  final _Brand brand;
  final ValueNotifier<Offset> pointer;
  final AnimationController drift;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Logo fills ~85 % of the shorter screen dimension so it bleeds edge-to-edge
        final logoSize = constraints.maxHeight * 0.85;

        return AnimatedBuilder(
          animation: Listenable.merge([pointer, drift]),
          builder: (context, _) {
            final breathe = 1.0 + 0.015 * math.sin(drift.value * 2 * math.pi);
            final p = pointer.value;
            final rotX = p.dy * 0.05;
            final rotY = -p.dx * 0.06;

            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: constraints.maxWidth * 0.5 - logoSize * 0.5,
                  top: constraints.maxHeight * 0.5 - logoSize * 0.5,
                  width: logoSize,
                  height: logoSize,
                  child: Transform(
                    alignment: Alignment.center,
                    // Small perspective entry + small rotation — enough to
                    // read as depth, never enough to look like a gimmick.
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0012)
                      ..rotateX(rotX)
                      ..rotateY(rotY)
                      ..scale(breathe),
                    child: ImageFiltered(
                      // Soft blur so the logo reads as ambient atmosphere, not a foreground element
                      imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                      child: ColorFiltered(
                        // Desaturate fully → push to near-white ghost at ~28 % opacity
                        colorFilter: const ColorFilter.matrix([
                          0.22, 0.22, 0.22, 0, 0,
                          0.22, 0.22, 0.22, 0, 0,
                          0.22, 0.22, 0.22, 0, 0,
                          0,    0,    0,    0.42, 0,
                        ]),
                        child: Image.asset(
                          brand.assetPath,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Floating card stage — wraps the login card with a slow idle float, a
// pointer-reactive 3D tilt, and a soft reflected glow beneath it, so the
// card behaves like a physical panel floating in the instrument cluster
// rather than a page element pinned to the center of the screen.
// ---------------------------------------------------------------------------

class _FloatingCardStage extends StatelessWidget {
  const _FloatingCardStage({
    required this.pointer,
    required this.drift,
    required this.child,
  });
  final ValueNotifier<Offset> pointer;
  final AnimationController drift;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([pointer, drift]),
      child: child,
      builder: (context, cardChild) {
        final t = drift.value;
        // Small Lissajous float — drifts on two axes at different
        // frequencies so the motion never feels like a simple bounce.
        final bobX = math.sin(t * 2 * math.pi * 0.6 + 1.0) * 3.0;
        final bobY = math.sin(t * 2 * math.pi) * 5.0;

        final p = pointer.value;
        final tiltX = p.dy * 0.035;
        final tiltY = -p.dx * 0.045;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Reflected floor glow — reads as light bouncing off a surface
            // beneath the panel, independent of the card's own tilt/bob.
            Transform.translate(
              offset: const Offset(0, 214),
              child: IgnorePointer(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 36),
                  child: Container(
                    width: 320,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(200),
                      color: _Ambient.cyan.withOpacity(0.12),
                    ),
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(bobX, bobY),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0016)
                  ..rotateX(tiltX)
                  ..rotateY(tiltY),
                child: cardChild,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Frosted glass login card
// ---------------------------------------------------------------------------

class _LoginCard extends ConsumerStatefulWidget {
  const _LoginCard({required this.brand, required this.fadeAnim});
  final _Brand brand;
  final Animation<double> fadeAnim;

  @override
  ConsumerState<_LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends ConsumerState<_LoginCard>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _submitted = false;

  // Slow diagonal sheen sweeping across the glass — the "light catching an
  // angled windshield" reflection that sells the glass as physical.
  late final AnimationController _sheenController;

  @override
  void initState() {
    super.initState();
    _sheenController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _sheenController.dispose();
    super.dispose();
  }

 /* Future<void> _handleLogin() async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;
    ref.read(authProvider.notifier).clearError();
    await ref.read(authProvider.notifier).signIn(
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
        );
  }*/


Future<void> _handleLogin() async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;
    
    // Seedha login aur dashboard pe redirect
    try {
      await ref.read(authProvider.notifier).signIn(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
    } catch (_) {}

    if (mounted) {
      context.go('/home');
    }
  }
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.loading;
    final errorMessage = authState.errorMessage;

    return Container(
      width: 400,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        // Layered shadow: a deep ambient-occlusion pass plus a faint cyan
        // bloom, so the panel reads as physically lifted off the backdrop.
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.55),
            blurRadius: 60,
            offset: const Offset(0, 30),
          ),
          BoxShadow(
            color: _Ambient.cyan.withOpacity(0.06),
            blurRadius: 90,
            spreadRadius: -10,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Stack(
          children: [
            BackdropFilter(
              // Blur the background behind the card — this is what creates the frosted look
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                width: 400,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.12),
                    width: 0.8,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(40, 40, 40, 36),
                child: Form(
                  key: _formKey,
                  autovalidateMode: _submitted
                      ? AutovalidateMode.onUserInteraction
                      : AutovalidateMode.disabled,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── App name (centered) ──────────────────────────
                      Text(
                        'AutoServe',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.heading2.copyWith(
                          color: Colors.white.withOpacity(0.95),
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── Heading ───────────────────────────────────────────
                      Text(
                        'Sign in',
                        style: AppTextStyles.heading2.copyWith(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // ── Brand tagline, fades with brand ───────────────────
                      FadeTransition(
                        opacity: widget.fadeAnim,
                        child: Text(
                          '"${widget.brand.tagline}"',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white.withOpacity(0.20),
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Email ─────────────────────────────────────────────
                      const _FieldLabel('Email address'),
                      const SizedBox(height: 5),
                      _GlassFieldShell(
                        child: _Field(
                          controller: _emailCtrl,
                          hint: 'you@dealership.com',
                          keyboardType: TextInputType.emailAddress,
                          enabled: !isLoading,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            if (!v.contains('@')) return 'Enter a valid email';
                            return null;
                          },
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ── Password ──────────────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const _FieldLabel('Password'),
                          GestureDetector(
                            onTap: () => context.go('/forgot-password'),
                            child: Text(
                              'Forgot?',
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white.withOpacity(0.18),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      _GlassFieldShell(
                        child: _Field(
                          controller: _passwordCtrl,
                          hint: '••••••••',
                          obscureText: _obscurePassword,
                          enabled: !isLoading,
                          onFieldSubmitted: (_) => _handleLogin(),
                          suffixIcon: GestureDetector(
                            onTap: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                            child: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 15,
                              color: Colors.white.withOpacity(0.20),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (v.length < 6) return 'Minimum 6 characters';
                            return null;
                          },
                        ),
                      ),

                      const SizedBox(height: 22),

                      // ── Error banner ──────────────────────────────────────
                      if (errorMessage != null) ...[
                        _ErrorBanner(message: errorMessage),
                        const SizedBox(height: 16),
                      ],

                      // ── Sign in button ────────────────────────────────────
                      // Auth is fully wired now — the router's redirect
                      // (listening to authProvider) sends the person to
                      // their resolved home route once sign-in resolves,
                      // so no manual navigation happens here.
                      _SignInButton(
                        isLoading: isLoading,
                        onPressed: _handleLogin,
                      ),

                      const SizedBox(height: 28),

                      Divider(
                        color: Colors.white.withOpacity(0.05),
                        height: 1,
                      ),

                      const SizedBox(height: 18),

                      Text(
                        'Restricted to dealership staff only.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white.withOpacity(0.12),
                          fontSize: 10,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Glass sheen sweep — a thin diagonal highlight drifting
            // left to right, like light catching an angled windshield.
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _sheenController,
                builder: (context, _) {
                  final dx = -1.3 + 2.6 * _sheenController.value;
                  return Align(
                    alignment: Alignment(dx, -1),
                    child: FractionallySizedBox(
                      heightFactor: 2.4,
                      child: Transform.rotate(
                        angle: -0.5,
                        child: Container(
                          width: 70,
                          color: Colors.white.withOpacity(0.035),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Glass field shell — gives each input its own small elevation and blur, so
// fields read as individual floating chips set into the card's surface
// rather than flat rows.
// ---------------------------------------------------------------------------

class _GlassFieldShell extends StatelessWidget {
  const _GlassFieldShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: _Ambient.cyan.withOpacity(0.05),
            blurRadius: 18,
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: child,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Field label
// ---------------------------------------------------------------------------

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.caption.copyWith(
        color: Colors.white.withOpacity(0.32),
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Input field
// ---------------------------------------------------------------------------

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.suffixIcon,
    this.validator,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      enabled: enabled,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      style: AppTextStyles.body.copyWith(
        color: Colors.white.withOpacity(0.85),
        fontSize: 13,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.body.copyWith(
          color: Colors.white.withOpacity(0.14),
          fontSize: 13,
        ),
        suffixIcon: suffixIcon != null
            ? Padding(
                padding: const EdgeInsets.only(right: 12),
                child: suffixIcon,
              )
            : null,
        suffixIconConstraints:
            const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide:
              BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide:
              BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide:
              BorderSide(color: Colors.white.withOpacity(0.30)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide:
              BorderSide(color: AppColors.error.withOpacity(0.5)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        errorStyle: AppTextStyles.caption.copyWith(
          color: AppColors.error,
          fontSize: 11,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error banner
// ---------------------------------------------------------------------------

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  bool get _isAccessError =>
      message.toLowerCase().contains('access denied') ||
      message.toLowerCase().contains('consumer') ||
      message.toLowerCase().contains('deactivated');

  @override
  Widget build(BuildContext context) {
    final color = _isAccessError ? AppColors.warning : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _isAccessError
                ? Icons.block_outlined
                : Icons.info_outline_rounded,
            color: color.withOpacity(0.8),
            size: 13,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.caption.copyWith(
                color: color.withOpacity(0.85),
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sign in button — same interaction, now with a faint LED-style glow that
// dims while a request is in flight.
// ---------------------------------------------------------------------------

class _SignInButton extends StatelessWidget {
  const _SignInButton({required this.isLoading, required this.onPressed});
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        boxShadow: isLoading
            ? []
            : [
                BoxShadow(
                  color: _Ambient.cyan.withOpacity(0.10),
                  blurRadius: 22,
                  spreadRadius: -4,
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(3),
        child: InkWell(
          borderRadius: BorderRadius.circular(3),
          onTap: isLoading ? null : onPressed,
          hoverColor: Colors.white.withOpacity(0.05),
          child: Ink(
            decoration: BoxDecoration(
              color: isLoading
                  ? Colors.white.withOpacity(0.04)
                  : Colors.white.withOpacity(0.09),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: Colors.white.withOpacity(0.10),
              ),
            ),
            child: Center(
              child: isLoading
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
                      'Sign in',
                      style: AppTextStyles.body.copyWith(
                        color: Colors.white.withOpacity(0.80),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

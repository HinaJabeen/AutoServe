// lib/layout/dashboard_shell.dart
// PART 1+2: All colors via context.palette. AutoServe steering-wheel logo.
// No GlobalKey in build(). All hardcoded colors removed.

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';

import '../features/providers/auth_provider.dart';
import '../features/providers/overview_provider.dart';
import '../features/providers/lead_provider.dart';
import '../core/router/app_router.dart';
import '../theme/app_palette.dart';
import '../theme/theme_provider.dart';

class DashboardShell extends ConsumerWidget {
  const DashboardShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.background,
      body: Row(
        children: [
          const _Sidebar(),
          Expanded(
            child: Container(
              color: p.background,
              child: Stack(
                fit: StackFit.expand,
                children: [const _AmbientGlow(), child],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Ambient glow ─────────────────────────────────────────────────────────────

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow();
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return IgnorePointer(
      child: Stack(children: [
        Positioned(
          top: -140, right: -100,
          child: _GlowBlob(size: 380, color: p.accent.withOpacity(0.07)),
        ),
        Positioned(
          bottom: -160, left: 120,
          child: _GlowBlob(size: 320, color: p.accentSecondary.withOpacity(0.05)),
        ),
      ]),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.size, required this.color});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => ImageFiltered(
    imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
    child: Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    ),
  );
}

// ─── Sidebar ──────────────────────────────────────────────────────────────────

class _Sidebar extends ConsumerWidget {
  const _Sidebar();
  static const double _width = 264;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc  = GoRouterState.of(context).matchedLocation;
    final p    = context.palette;
    final da   = ref.watch(currentDealershipProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: _width,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: p.surface.withOpacity(isDark ? 0.92 : 0.95),
              border: Border(right: BorderSide(color: p.border)),
              boxShadow: [
                BoxShadow(
                  color: p.shadowColor.withOpacity(0.3),
                  blurRadius: 24, offset: const Offset(4, 0),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _BrandHeader(),
                Divider(color: p.border, height: 1),
                _DealerRow(dealershipAsync: da),
                Divider(color: p.border, height: 1),
                const SizedBox(height: 8),
                _NavItem(icon: Icons.space_dashboard_rounded,       label: 'Overview',  route: AppRoutes.overview,  active: loc == AppRoutes.overview),
                _NavItem(icon: Icons.directions_car_filled_rounded,  label: 'Inventory', route: AppRoutes.inventory, active: loc == AppRoutes.inventory),
                _NavItem(icon: Icons.groups_rounded,                 label: 'Leads',     route: AppRoutes.leads,     active: loc == AppRoutes.leads),
                _NavItem(icon: Icons.calendar_month_rounded,         label: 'Schedule',  route: AppRoutes.schedule,  active: loc == AppRoutes.schedule),
                _NavItem(icon: Icons.person_outline_rounded,         label: 'Profile',   route: AppRoutes.profile,   active: loc == AppRoutes.profile),
                const Spacer(),
                Divider(color: p.border, height: 1),
                const _ThemeToggleTile(),
                const _SignOutTile(),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Brand header with steering-wheel logo ────────────────────────────────────

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
      child: Row(children: [
        // AutoServe steering-wheel logo — color matches palette accent
        CustomPaint(
          painter: _SteeringWheelPainter(accentColor: p.accent),
          size: const Size(30, 30),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AutoServe',
                style: AppTextStyles.bodyBold.copyWith(
                  color: p.textPrimary,
                  fontSize: 15,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w700,
                )),
            Text('Dealer OS',
                style: AppTextStyles.caption.copyWith(
                  color: p.accent.withOpacity(0.7),
                  fontSize: 9,
                  letterSpacing: 1.6,
                )),
          ],
        ),
      ]),
    );
  }
}

/// Draws the AutoServe steering wheel logo using the palette accent color.
class _SteeringWheelPainter extends CustomPainter {
  const _SteeringWheelPainter({required this.accentColor});
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2;

    final paint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    // Outer ring
    canvas.drawCircle(Offset(cx, cy), r * 0.92, paint);

    // Inner hub circle
    canvas.drawCircle(Offset(cx, cy), r * 0.18, paint);

    // Three spokes at 90°, 210°, 330° (classic 3-spoke wheel)
    final spokeAngles = [90.0, 210.0, 330.0];
    for (final deg in spokeAngles) {
      final rad = deg * math.pi / 180;
      final innerX = cx + r * 0.18 * math.cos(rad);
      final innerY = cy + r * 0.18 * math.sin(rad);
      final outerX = cx + r * 0.75 * math.cos(rad);
      final outerY = cy + r * 0.75 * math.sin(rad);
      canvas.drawLine(Offset(innerX, innerY), Offset(outerX, outerY), paint);
    }

    // Top arc segments (rim grip areas between spokes)
    final rimPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    // Draw 3 arc segments on the outer rim between the spoke endpoints
    for (int i = 0; i < 3; i++) {
      final startDeg = spokeAngles[i] + 20;
      final sweepDeg = (spokeAngles[(i + 1) % 3] - spokeAngles[i] - 40 + 360) % 360;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.92),
        startDeg * math.pi / 180,
        sweepDeg * math.pi / 180,
        false,
        rimPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SteeringWheelPainter old) =>
      old.accentColor != accentColor;
}

// ─── Dealer row ───────────────────────────────────────────────────────────────

class _DealerRow extends ConsumerWidget {
  const _DealerRow({required this.dealershipAsync});
  final AsyncValue<DealershipModel?> dealershipAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p         = context.palette;
    final auth      = ref.watch(authProvider);
    final staffName = auth.displayName ?? 'Staff';
    final dealer    = dealershipAsync.value;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      child: Row(children: [
        _DealerAvatar(logoUrl: dealer?.logoUrl, accent: p.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(dealer?.name ?? '—',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyBold.copyWith(
                    color: p.textPrimary.withOpacity(0.92), fontSize: 12.5)),
            Text(staffName,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                    color: p.textMuted, fontSize: 10)),
          ]),
        ),
        _NotificationBell(),
      ]),
    );
  }
}

class _DealerAvatar extends StatelessWidget {
  const _DealerAvatar({this.logoUrl, required this.accent});
  final String? logoUrl;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34, height: 34,
      decoration: BoxDecoration(
        color: accent.withOpacity(0.14),
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        border: Border.all(color: accent.withOpacity(0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: (logoUrl != null && logoUrl!.isNotEmpty)
          ? Image.network(logoUrl!, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _icon(accent))
          : _icon(accent),
    );
  }

  Widget _icon(Color c) =>
      Icon(Icons.directions_car_rounded, color: c, size: 18);
}

// ─── Notification bell ─────────────────────────────────────────────────────

class _NotificationBell extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count    = ref.watch(unreadLeadCountProvider);
    final hasUnread = count > 0;
    final p = context.palette;

    return Stack(clipBehavior: Clip.none, children: [
      Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: hasUnread
              ? [BoxShadow(color: p.accent.withOpacity(0.4),
                  blurRadius: 14, spreadRadius: 1)]
              : [],
        ),
        child: IconButton(
          icon: Icon(
            hasUnread ? Icons.notifications_rounded : Icons.notifications_none_rounded,
            color: hasUnread ? p.accent : p.textMuted,
            size: AppDimensions.iconSizeM,
          ),
          tooltip: 'Notifications',
          onPressed: () {
            context.go(AppRoutes.leads);
            ref.read(unreadLeadCountProvider.notifier).state = 0;
          },
        ),
      ),
      if (hasUnread)
        Positioned(
          top: 6, right: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            decoration: BoxDecoration(
              color: p.accent,
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              boxShadow: [BoxShadow(
                  color: p.accent.withOpacity(0.7), blurRadius: 6)],
            ),
            child: Center(
              child: Text(count > 9 ? '9+' : '$count',
                  style: TextStyle(
                      color: p.background, fontSize: 9,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ),
    ]);
  }
}

// ─── Nav item ─────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon, required this.label,
    required this.route, required this.active,
  });
  final IconData icon;
  final String label, route;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          hoverColor: p.accent.withOpacity(0.06),
          onTap: () => context.go(route),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: active ? p.accent.withOpacity(0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(AppDimensions.radiusM),
              border: active
                  ? Border.all(color: p.accent.withOpacity(0.25))
                  : Border.all(color: Colors.transparent),
              boxShadow: active
                  ? [BoxShadow(color: p.accent.withOpacity(0.15),
                      blurRadius: 16, spreadRadius: -4)]
                  : [],
            ),
            child: Row(children: [
              Icon(icon,
                  size: AppDimensions.iconSizeM,
                  color: active ? p.accent : p.textMuted),
              const SizedBox(width: 12),
              Text(label,
                  style: AppTextStyles.body.copyWith(
                    color: active ? p.textPrimary : p.textSecondary,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 13,
                  )),
              if (active) ...[
                const Spacer(),
                Container(width: 4, height: 4,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: p.accent)),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── Theme toggle ─────────────────────────────────────────────────────────────

class _ThemeToggleTile extends ConsumerWidget {
  const _ThemeToggleTile();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          hoverColor: p.accent.withOpacity(0.06),
          onTap: () => ref.read(themeProvider.notifier).toggle(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  key: ValueKey(isDark),
                  size: AppDimensions.iconSizeM,
                  color: p.textMuted,
                ),
              ),
              const SizedBox(width: 12),
              Text(isDark ? 'Light Mode' : 'Dark Mode',
                  style: AppTextStyles.body.copyWith(
                      color: p.textSecondary, fontSize: 13)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── Sign out ─────────────────────────────────────────────────────────────────

class _SignOutTile extends ConsumerWidget {
  const _SignOutTile();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = ref.watch(authProvider).status == AuthStatus.loading;
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          hoverColor: p.error.withOpacity(0.08),
          onTap: loading ? null : () => ref.read(authProvider.notifier).signOut(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(children: [
              Icon(Icons.logout_rounded,
                  size: AppDimensions.iconSizeM, color: p.textMuted),
              const SizedBox(width: 12),
              Text('Sign out',
                  style: AppTextStyles.body.copyWith(
                      color: p.textSecondary, fontSize: 13)),
            ]),
          ),
        ),
      ),
    );
  }
}
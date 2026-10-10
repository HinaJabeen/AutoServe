// lib/features/presentation/profile_settings_screen.dart
// FIXED: Added import 'package:shared/shared.dart'

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared/shared.dart';
import 'package:dashboard/theme/app_palette.dart';

import '../providers/auth_provider.dart';

class ProfileSettingsScreen extends ConsumerWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState   = ref.watch(authProvider);
    final displayName = authState.displayName ?? '—';
    final email       = Supabase.instance.client.auth.currentUser?.email ?? '—';
    final palette     = Theme.of(context).extension<AppPalette>()!;
    final isDark      = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingXL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Profile Settings',
              style: AppTextStyles.heading1.copyWith(
                  color: palette.textPrimary, fontSize: 26)),
          const SizedBox(height: AppDimensions.paddingXL),

          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusL),
              border: Border.all(color: palette.border),
              boxShadow: [
                BoxShadow(
                  color: palette.shadowColor.withOpacity(isDark ? 0.35 : 0.06),
                  blurRadius: 24, offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.pastelPink.withOpacity(0.22),
                            AppColors.pastelPinkDeep.withOpacity(0.14),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.pastelPink.withOpacity(0.35)),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.pastelPink.withOpacity(0.25),
                            blurRadius: 16, spreadRadius: -4,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : '?',
                          style: AppTextStyles.heading2.copyWith(
                              color: AppColors.pastelPink, fontSize: 22),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.paddingM),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(displayName,
                            style: AppTextStyles.bodyBold.copyWith(
                                color: palette.textPrimary, fontSize: 16)),
                        const SizedBox(height: 4),
                        _RoleBadge(role: authState.role),
                      ],
                    ),
                  ],
                ),

                Divider(
                  color: palette.border,
                  height: AppDimensions.paddingXL,
                ),

                _InfoField(label: 'Full Name', value: displayName),
                const SizedBox(height: AppDimensions.paddingM),
                _InfoField(label: 'Email', value: email),
                const SizedBox(height: AppDimensions.paddingM),
                _InfoField(label: 'Role', value: _roleLabel(authState.role)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _roleLabel(AppRole role) {
    switch (role) {
      case AppRole.admin:       return 'Admin';
      case AppRole.dealerOwner: return 'Dealer Owner';
      case AppRole.staff:       return 'Staff';
      case AppRole.none:        return '—';
    }
  }
}

class _InfoField extends StatelessWidget {
  const _InfoField({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.caption.copyWith(
                color: palette.textTertiary,
                fontSize: 11, fontWeight: FontWeight.w600,
                letterSpacing: 0.4)),
        const SizedBox(height: 4),
        Text(value,
            style: AppTextStyles.body.copyWith(
                color: palette.textSecondary, fontSize: 13.5)),
      ],
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final AppRole role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.pastelPink.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(color: AppColors.pastelPink.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: AppColors.pastelPink.withOpacity(0.15),
            blurRadius: 8, spreadRadius: -2,
          ),
        ],
      ),
      child: Text(
        _label(role),
        style: AppTextStyles.caption.copyWith(
          color: AppColors.pastelPink,
          fontSize: 11, fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _label(AppRole r) {
    switch (r) {
      case AppRole.admin:       return 'Admin';
      case AppRole.dealerOwner: return 'Dealer Owner';
      case AppRole.staff:       return 'Staff';
      case AppRole.none:        return '—';
    }
  }
}
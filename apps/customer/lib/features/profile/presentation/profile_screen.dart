// lib/features/profile/presentation/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../../core/theme/app_theme.dart';

import '../../../core/theme/theme_provider.dart';
import '../../auth/models/customer_profile.dart';
import '../../auth/providers/auth_providers.dart';
import '../../dealer_application/presentation/dealer_status_card.dart';

const _kProfileMaxWidth = 480.0;

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    // On success authProvider flips to unauthenticated and the router
    // replaces this screen with /login — nothing to navigate here.
    final error = await ref.read(authProvider.notifier).signOut();
    if (!mounted) return;
    setState(() => _signingOut = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        // Null only for the instant between signing out and the router's
        // redirect to /login.
        child: profile == null
            ? const SizedBox.shrink()
            : Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppDimensions.paddingL),
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: _kProfileMaxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ProfileHeader(profile: profile),
                        const SizedBox(height: AppDimensions.paddingL),
                        _SectionCard(
                          children: [
                            _DetailRow(
                              icon: Icons.person_outline_rounded,
                              label: 'Name',
                              value: profile.fullName,
                            ),
                            _DetailRow(
                              icon: Icons.mail_outline_rounded,
                              label: 'Email',
                              value: profile.email,
                            ),
                            _DetailRow(
                              icon: Icons.phone_outlined,
                              label: 'Phone',
                              value: profile.phone ?? '',
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.paddingM),
                        const _SectionCard(children: [_AppearanceRow()]),
                        const SizedBox(height: AppDimensions.paddingM),
                        const DealerStatusCard(),
                        const SizedBox(height: AppDimensions.paddingL),
                        AppButton(
                          label: 'Log out',
                          icon: Icons.logout_rounded,
                          variant: AppButtonVariant.outline,
                          isLoading: _signingOut,
                          onPressed: _signOut,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});
  final CustomerProfile profile;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: p.accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: p.accentGlow, blurRadius: 24, spreadRadius: 2),
            ],
          ),
          child: Text(
            profile.initials,
            style: AppTextStyles.heading1.copyWith(color: p.onAccent),
          ),
        ),
        const SizedBox(height: AppDimensions.paddingM),
        Text(
          profile.fullName.isEmpty ? 'AutoServe customer' : profile.fullName,
          textAlign: TextAlign.center,
          style: AppTextStyles.heading2.copyWith(color: p.textPrimary),
        ),
        const SizedBox(height: AppDimensions.paddingXS),
        Text(
          profile.email,
          textAlign: TextAlign.center,
          style: AppTextStyles.body.copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: AppDimensions.paddingM),
        // Only customer accounts get past sign-in (AuthNotifier._resolveProfile),
        // so this always reads "Customer Account" in practice.
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingM, vertical: 6),
          decoration: BoxDecoration(
            color: p.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            border: Border.all(color: p.accent.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_user_outlined, size: 14, color: p.accentSecondary),
              const SizedBox(width: 6),
              Text(
                profile.isCustomer ? 'Customer Account' : 'Staff Account',
                style: AppTextStyles.caption.copyWith(
                    color: p.accentSecondary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(AppRadii.glass),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: p.borderSubtle),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hasValue = value.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: Row(
        children: [
          Icon(icon, size: 20, color: p.accentSecondary),
          const SizedBox(width: AppDimensions.paddingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(color: p.textTertiary),
                ),
                const SizedBox(height: 2),
                Text(
                  hasValue ? value : 'Not provided',
                  style: AppTextStyles.bodyBold.copyWith(
                    color: hasValue ? p.textPrimary : p.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppearanceRow extends ConsumerWidget {
  const _AppearanceRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final mode = ref.watch(themeProvider);
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Appearance',
            style: AppTextStyles.caption.copyWith(color: p.textTertiary),
          ),
          const SizedBox(height: AppDimensions.paddingS),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto_outlined, size: 18),
                label: Text('Auto'),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined, size: 18),
                label: Text('Light'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined, size: 18),
                label: Text('Dark'),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (selection) =>
                ref.read(themeProvider.notifier).setMode(selection.first),
          ),
        ],
      ),
    );
  }
}

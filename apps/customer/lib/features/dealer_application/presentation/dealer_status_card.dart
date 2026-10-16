// lib/features/dealer_application/presentation/dealer_status_card.dart
//
// Profile-screen card that reflects the user's dealership application:
// none → "Sell on AutoServe"; pending → under review; rejected → reason +
// resubmit; approved → verified badge + dealer portal; suspended → notice.

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';

import '../../../core/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/app_router.dart';
import '../models/dealer_application.dart';
import '../providers/dealer_application_providers.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "14 Oct 2026, 3:05 PM"
String _formatDate(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${_months[d.month - 1]} ${d.year}, $h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
}

class DealerStatusCard extends ConsumerWidget {
  const DealerStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    return ref.watch(myDealerApplicationProvider).when(
          loading: () => const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          // The rest of the profile still works; just say so quietly.
          error: (e, _) => Text('Could not load dealership status.',
              style: AppTextStyles.caption.copyWith(color: p.textTertiary)),
          data: (app) => switch (app?.status) {
            null => const _RegisterCard(),
            ApplicationStatus.pending => _PendingCard(app: app!),
            ApplicationStatus.rejected => _RejectedCard(app: app!),
            ApplicationStatus.approved => _ApprovedCard(app: app!),
            ApplicationStatus.suspended => _SuspendedCard(app: app!),
          },
        );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.accent,
    required this.icon,
    required this.title,
    required this.children,
  });
  final Color accent;
  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.glass),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: accent),
            ),
            const SizedBox(width: AppDimensions.paddingM),
            Expanded(
              child: Text(title, style: AppTextStyles.heading3.copyWith(color: p.textPrimary)),
            ),
          ]),
          const SizedBox(height: AppDimensions.paddingM),
          ...children,
        ],
      ),
    );
  }
}

Text _body(BuildContext context, String text) => Text(text,
    style: AppTextStyles.body.copyWith(color: context.palette.textSecondary));

class _RegisterCard extends StatelessWidget {
  const _RegisterCard();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _CardShell(
      accent: p.accent,
      icon: Icons.storefront_rounded,
      title: 'Sell on AutoServe',
      children: [
        _body(context,
            'Own a car showroom? Register your dealership to list inventory and '
            'receive buyer leads.'),
        const SizedBox(height: AppDimensions.paddingM),
        ElevatedButton.icon(
          onPressed: () => context.push(AppRoutes.becomeDealer),
          icon: Icon(Icons.add_business_rounded, size: 18, color: p.onAccent),
          label: Text('Register Dealership',
              style: AppTextStyles.button.copyWith(color: p.onAccent)),
        ),
      ],
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.app});
  final DealerApplication app;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _CardShell(
      accent: p.warning,
      icon: Icons.schedule_rounded,
      title: 'Application Under Review',
      children: [
        Text(app.showroomName, style: AppTextStyles.bodyBold.copyWith(color: p.textPrimary)),
        if (app.submittedAt != null)
          Text('Submitted ${_formatDate(app.submittedAt!)}',
              style: AppTextStyles.caption.copyWith(color: p.textTertiary)),
        const SizedBox(height: AppDimensions.paddingS),
        _body(context,
            'Your dealership application is being verified by AutoServe admin to '
            'ensure platform trust and safety.'),
        const SizedBox(height: AppDimensions.paddingS),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.push(AppRoutes.becomeDealer),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Edit application'),
          ),
        ),
      ],
    );
  }
}

class _RejectedCard extends StatelessWidget {
  const _RejectedCard({required this.app});
  final DealerApplication app;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _CardShell(
      accent: p.error,
      icon: Icons.cancel_outlined,
      title: 'Application Rejected',
      children: [
        _body(context, 'Reason from the AutoServe team:'),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(AppDimensions.paddingS),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusS),
          ),
          child: Text(app.rejectionReason ?? 'No reason was given.',
              style: AppTextStyles.body.copyWith(color: p.textPrimary)),
        ),
        const SizedBox(height: AppDimensions.paddingM),
        ElevatedButton.icon(
          onPressed: () => context.push(AppRoutes.becomeDealer),
          icon: Icon(Icons.refresh_rounded, size: 18, color: p.onAccent),
          label: Text('Update & Resubmit', style: AppTextStyles.button.copyWith(color: p.onAccent)),
        ),
      ],
    );
  }
}

/// Build-time default (`--dart-define=DEALER_PORTAL_URL=...`), falling back
/// to a locally served dashboard (`flutter run -d chrome --web-port 5000`
/// in apps/dashboard).
const _defaultPortalUrl =
    String.fromEnvironment('DEALER_PORTAL_URL', defaultValue: 'http://localhost:5000');

/// `.env` DEALER_PORTAL_URL if set and non-empty, else [_defaultPortalUrl].
String dealerPortalUrl() {
  final fromEnv =
      dotenv.isInitialized ? dotenv.maybeGet('DEALER_PORTAL_URL')?.trim() : null;
  return (fromEnv == null || fromEnv.isEmpty) ? _defaultPortalUrl : fromEnv;
}

class _ApprovedCard extends StatelessWidget {
  const _ApprovedCard({required this.app});
  final DealerApplication app;

  Future<void> _openPortal(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final url = dealerPortalUrl();
    final uri = Uri.tryParse(url);
    final ok = uri != null &&
        await launchUrl(
          uri,
          // Web: new browser tab. Mobile/desktop: the system browser.
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: '_blank',
        );
    if (!ok) {
      messenger.showSnackBar(SnackBar(content: Text("Couldn't open the dealer portal ($url).")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _CardShell(
      accent: p.success,
      icon: Icons.verified_rounded,
      title: 'Verified Dealer',
      children: [
        Text(app.showroomName, style: AppTextStyles.bodyBold.copyWith(color: p.textPrimary)),
        if (app.verifiedAt != null)
          Text('Verified ${_formatDate(app.verifiedAt!)}',
              style: AppTextStyles.caption.copyWith(color: p.textTertiary)),
        const SizedBox(height: AppDimensions.paddingS),
        _body(context,
            'Manage your inventory and leads in the AutoServe Dealer Portal. '
            'Sign in there with this same email and password.'),
        const SizedBox(height: AppDimensions.paddingM),
        ElevatedButton.icon(
          onPressed: () => _openPortal(context),
          icon: Icon(Icons.open_in_new_rounded, size: 18, color: p.onAccent),
          label: Text('Open Dealer Portal', style: AppTextStyles.button.copyWith(color: p.onAccent)),
          style: ElevatedButton.styleFrom(backgroundColor: p.success),
        ),
      ],
    );
  }
}

class _SuspendedCard extends StatelessWidget {
  const _SuspendedCard({required this.app});
  final DealerApplication app;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _CardShell(
      accent: p.error,
      icon: Icons.block_rounded,
      title: 'Dealership Suspended',
      children: [
        _body(context,
            '${app.showroomName} is currently suspended and hidden from buyers. '
            'Contact AutoServe support to resolve this.'),
      ],
    );
  }
}

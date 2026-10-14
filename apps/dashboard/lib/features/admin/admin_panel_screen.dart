// lib/features/admin/admin_panel_screen.dart
//
// Super-admin platform view at /admin (the router only lets AppRole.admin
// in). Lists every dealership with its car/lead counts, platform totals,
// approve/suspend controls, and a "register dealership" form.

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';

import '../../widgets/theme_toggle_button.dart';
import '../providers/auth_provider.dart';
import 'admin_providers.dart';

class AdminPanelScreen extends ConsumerWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSuperAdmin = ref.watch(authProvider.select((a) => a.isSuperAdmin));
    return isSuperAdmin ? const _AdminPanel() : const _AccessDenied();
  }
}

class _AdminPanel extends ConsumerWidget {
  const _AdminPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final hasDealership = ref.watch(authProvider.select((a) => a.dealershipId != null));
    final summaryAsync = ref.watch(platformSummaryProvider);
    final adminName = ref.watch(authProvider).displayName;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        title: Text('AutoServe Platform Admin',
            style: AppTextStyles.heading3.copyWith(color: p.textPrimary)),
        actions: [
          if (adminName != null)
            Center(
              child: Text(adminName,
                  style: AppTextStyles.caption.copyWith(color: p.textSecondary)),
            ),
          const SizedBox(width: 8),
          if (hasDealership)
            TextButton.icon(
              onPressed: () => context.go('/overview'),
              icon: const Icon(Icons.dashboard_outlined, size: 18),
              label: const Text('Dealer dashboard'),
            ),
          const ThemeToggleButton(),
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh_rounded, color: p.textSecondary),
            onPressed: () => ref.invalidate(platformSummaryProvider),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: Icon(Icons.logout_rounded, color: p.textSecondary),
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Could not load platform data: $e',
                style: AppTextStyles.body.copyWith(color: p.error)),
            TextButton(
              onPressed: () => ref.invalidate(platformSummaryProvider),
              child: const Text('Retry'),
            ),
          ]),
        ),
        data: (summary) => ListView(
          padding: const EdgeInsets.all(AppDimensions.paddingXL),
          children: [
            Wrap(
              spacing: AppDimensions.paddingM,
              runSpacing: AppDimensions.paddingM,
              children: [
                _Stat(icon: Icons.storefront_outlined, value: '${summary.totalDealers}',
                    label: 'Dealerships'),
                _Stat(icon: Icons.verified_outlined, value: '${summary.approvedDealers}',
                    label: 'Approved'),
                _Stat(icon: Icons.hourglass_empty_rounded, value: '${summary.pendingDealers}',
                    label: 'Pending approval'),
                _Stat(icon: Icons.directions_car_outlined, value: '${summary.totalCars}',
                    label: 'Cars on platform'),
                _Stat(icon: Icons.forum_outlined, value: '${summary.totalLeads}',
                    label: 'Leads platform-wide'),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingXL),
            Row(children: [
              Expanded(
                child: Text('Dealerships',
                    style: AppTextStyles.heading2.copyWith(color: p.textPrimary, fontSize: 18)),
              ),
              ElevatedButton.icon(
                onPressed: () => showDialog(
                    context: context, builder: (_) => const _RegisterDealerDialog()),
                icon: const Icon(Icons.add_business_outlined, size: 18),
                label: const Text('Register dealership'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: p.accent, foregroundColor: p.onAccent),
              ),
            ]),
            const SizedBox(height: AppDimensions.paddingM),
            if (summary.dealers.isEmpty)
              Text('No dealerships yet.',
                  style: AppTextStyles.body.copyWith(color: p.textSecondary))
            else
              for (final row in summary.dealers) _DealerTile(row: row),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: 200,
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: Border.all(color: p.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: p.accent, size: 20),
        const SizedBox(height: AppDimensions.paddingM),
        Text(value, style: AppTextStyles.heading1.copyWith(color: p.textPrimary, fontSize: 24)),
        Text(label, style: AppTextStyles.caption.copyWith(color: p.textTertiary)),
      ]),
    );
  }
}

class _DealerTile extends ConsumerStatefulWidget {
  const _DealerTile({required this.row});
  final AdminDealerRow row;

  @override
  ConsumerState<_DealerTile> createState() => _DealerTileState();
}

class _DealerTileState extends ConsumerState<_DealerTile> {
  bool _busy = false;

  Future<void> _setStatus(String status) async {
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = context.palette.error;
    setState(() => _busy = true);
    final error = await setDealerStatus(ref, widget.row.dealer.id, status);
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(SnackBar(
      content: Text(error ?? '${widget.row.dealer.name} is now $status'),
      backgroundColor: error == null ? null : errorColor,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = widget.row.dealer;
    final statusColor = switch (d.status) {
      'approved' => p.success,
      'pending' => p.warning,
      _ => p.error,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingS),
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(color: p.border),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(d.name,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyBold.copyWith(color: p.textPrimary)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(d.status,
                    style: AppTextStyles.caption.copyWith(
                        color: statusColor, fontWeight: FontWeight.w600, fontSize: 11)),
              ),
            ]),
            const SizedBox(height: 2),
            Text([d.city, if (d.phone.isNotEmpty) d.phone, d.businessHours]
                    .whereType<String>()
                    .where((s) => s.trim().isNotEmpty)
                    .join(' · '),
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(color: p.textSecondary)),
          ]),
        ),
        _Count(icon: Icons.directions_car_outlined, value: widget.row.carCount, label: 'cars'),
        _Count(icon: Icons.forum_outlined, value: widget.row.leadCount, label: 'leads'),
        const SizedBox(width: AppDimensions.paddingS),
        if (_busy)
          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
        else if (d.status == 'approved')
          OutlinedButton(
            onPressed: () => _setStatus('suspended'),
            style: OutlinedButton.styleFrom(
                foregroundColor: p.error, side: BorderSide(color: p.error)),
            child: const Text('Suspend'),
          )
        else
          ElevatedButton(
            onPressed: () => _setStatus('approved'),
            style: ElevatedButton.styleFrom(
                backgroundColor: p.accent, foregroundColor: p.onAccent),
            child: Text(d.status == 'pending' ? 'Approve' : 'Reactivate'),
          ),
      ]),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.icon, required this.value, required this.label});
  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: p.textTertiary),
        const SizedBox(width: 4),
        Text('$value $label',
            style: AppTextStyles.body.copyWith(color: p.textPrimary, fontSize: 13)),
      ]),
    );
  }
}

class _RegisterDealerDialog extends ConsumerStatefulWidget {
  const _RegisterDealerDialog();

  @override
  ConsumerState<_RegisterDealerDialog> createState() => _RegisterDealerDialogState();
}

class _RegisterDealerDialogState extends ConsumerState<_RegisterDealerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();
  bool _approve = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _phone, _city, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await registerDealer(
      ref,
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      city: _city.text.trim(),
      address: _address.text.trim(),
      approve: _approve,
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    String? required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

    Widget field(TextEditingController c, String label,
            {String? Function(String?)? validator, TextInputType? keyboard}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.paddingM),
          child: TextFormField(
            controller: c,
            enabled: !_saving,
            keyboardType: keyboard,
            validator: validator,
            style: AppTextStyles.body.copyWith(color: p.textPrimary, fontSize: 13.5),
            decoration: InputDecoration(labelText: label, filled: true, fillColor: p.surface),
          ),
        );

    return AlertDialog(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      title: Text('Register dealership', style: TextStyle(color: p.textPrimary)),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              field(_name, 'Showroom name', validator: required),
              field(_phone, 'Phone / WhatsApp', keyboard: TextInputType.phone, validator: (v) =>
                  ContactLinks.internationalDigits(v) == null ? 'Enter a valid phone number' : null),
              field(_city, 'City', validator: required),
              field(_address, 'Address (optional)'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _approve,
                onChanged: _saving ? null : (v) => setState(() => _approve = v),
                title: Text('Approve immediately',
                    style: AppTextStyles.body.copyWith(color: p.textPrimary, fontSize: 13.5)),
                subtitle: Text('Approved dealers are visible in the customer app.',
                    style: AppTextStyles.caption.copyWith(color: p.textSecondary)),
              ),
              Text(
                "This creates the dealership record only. The owner's login is set up "
                'separately and linked through dealer_staff.',
                style: AppTextStyles.caption.copyWith(color: p.textTertiary),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppDimensions.paddingS),
                Text(_error!, style: AppTextStyles.caption.copyWith(color: p.error)),
              ],
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: p.accent, foregroundColor: p.onAccent),
          child: _saving
              ? SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: p.onAccent))
              : const Text('Register'),
        ),
      ],
    );
  }
}

/// Shown at /admin to anyone signed in without an `admin_users` row.
class _AccessDenied extends ConsumerStatefulWidget {
  const _AccessDenied();

  @override
  ConsumerState<_AccessDenied> createState() => _AccessDeniedState();
}

class _AccessDeniedState extends ConsumerState<_AccessDenied> {
  bool _rechecking = false;

  Future<void> _recheck() async {
    setState(() => _rechecking = true);
    await ref.read(authProvider.notifier).refreshSession();
    if (mounted) setState(() => _rechecking = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final auth = ref.watch(authProvider);
    final user = SupabaseService.client.auth.currentUser;
    final uid = user?.id ?? auth.userId ?? '<your-user-id>';
    final name = (auth.displayName ?? user?.email ?? 'Admin').replaceAll("'", "''");
    // Only an existing admin (or the SQL editor) can write admin_users — RLS
    // blocks self-promotion from the client, as it should — so the dev aid is
    // SQL to run, not a button.
    final sql = "insert into public.admin_users (user_id, full_name)\n"
        "values ('$uid', '$name');\n"
        "-- If that fails with 'null value in column \"id\"', use instead:\n"
        "-- insert into public.admin_users (id, user_id, full_name)\n"
        "-- values ('$uid', '$uid', '$name');";

    return Scaffold(
      backgroundColor: p.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.paddingXL),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.admin_panel_settings_outlined, size: 56, color: p.error),
                const SizedBox(height: AppDimensions.paddingM),
                Text('Access Denied',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.heading1.copyWith(color: p.textPrimary, fontSize: 24)),
                const SizedBox(height: AppDimensions.paddingS),
                Text('Super Admin privileges are required to view the platform panel.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(color: p.textSecondary)),
                const SizedBox(height: AppDimensions.paddingS),
                SelectableText('Signed in as ${user?.email ?? 'unknown'} · $uid',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(color: p.textTertiary)),
                if (kDebugMode) ...[
                  const SizedBox(height: AppDimensions.paddingL),
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.paddingM),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                      border: Border.all(color: p.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DEV MODE — make this account an admin',
                            style: AppTextStyles.caption.copyWith(
                                color: p.warning, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('Run this in the Supabase SQL editor, then press "Re-check access".',
                            style: AppTextStyles.caption.copyWith(color: p.textSecondary)),
                        const SizedBox(height: AppDimensions.paddingS),
                        SelectableText(sql,
                            style: TextStyle(
                                fontFamily: 'monospace', fontSize: 12, color: p.textPrimary)),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: sql));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('SQL copied')));
                              }
                            },
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            label: const Text('Copy SQL'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppDimensions.paddingL),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppDimensions.paddingS,
                  runSpacing: AppDimensions.paddingS,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _rechecking ? null : _recheck,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(_rechecking ? 'Checking…' : 'Re-check access'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: p.accent, foregroundColor: p.onAccent),
                    ),
                    if (auth.dealershipId != null)
                      OutlinedButton.icon(
                        onPressed: () => context.go('/overview'),
                        icon: const Icon(Icons.dashboard_outlined, size: 18),
                        label: const Text('Back to dashboard'),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => ref.read(authProvider.notifier).signOut(),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Sign out'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

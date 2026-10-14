// lib/features/presentation/dealership_settings_screen.dart
//
// Showroom profile shown to customers (vehicle detail dealer card, WhatsApp
// button). Only owners can save — the "owners_update_own_dealer" RLS policy
// enforces the same rule server-side; staff see the form read-only.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/auth_provider.dart';
import '../providers/overview_provider.dart';

class DealershipSettingsScreen extends ConsumerWidget {
  const DealershipSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final dealerAsync = ref.watch(currentDealershipProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingXL),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dealership Settings',
                  style: AppTextStyles.heading1.copyWith(color: p.textPrimary, fontSize: 26)),
              const SizedBox(height: 4),
              Text('How your showroom appears to customers in the AutoServe app.',
                  style: AppTextStyles.caption.copyWith(color: p.textTertiary, fontSize: 13)),
              const SizedBox(height: AppDimensions.paddingXL),
              dealerAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Could not load dealership: $e',
                    style: AppTextStyles.body.copyWith(color: p.error)),
                data: (dealer) => dealer == null
                    ? Text('No dealership is linked to this account.',
                        style: AppTextStyles.body.copyWith(color: p.textSecondary))
                    : _SettingsForm(
                        key: ValueKey(dealer.id),
                        dealer: dealer,
                        canEdit: ref.watch(currentRoleProvider) == AppRole.dealerOwner,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({super.key, required this.dealer, required this.canEdit});
  final DealershipModel dealer;
  final bool canEdit;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.dealer.name);
  late final _phone = TextEditingController(text: widget.dealer.phone);
  late final _city = TextEditingController(text: widget.dealer.city);
  late final _address = TextEditingController(text: widget.dealer.address ?? '');
  late final _hours = TextEditingController(text: widget.dealer.businessHours ?? '');
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _city, _address, _hours]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final p = context.palette;

    // Live `dealers` columns: id, name, city, contact_phone, status,
    // created_at, business_hours (+ address once 20261014150000 is applied).
    // There is no `phone` column — DealershipModel.phone reads contact_phone.
    final hours = _hours.text.trim();
    final address = _address.text.trim();
    final update = <String, dynamic>{
      'name': _name.text.trim(),
      'contact_phone': _phone.text.trim(),
      'city': _city.text.trim(),
      // Only sent when changed, so the rest still saves on a database where
      // the column's migration hasn't been applied yet.
      if (address != (widget.dealer.address ?? '')) 'address': address.isEmpty ? null : address,
      if (hours != (widget.dealer.businessHours ?? '')) 'business_hours': hours.isEmpty ? null : hours,
    };

    try {
      final rows = await SupabaseService.client
          .from('dealers')
          .update(update)
          .eq('id', widget.dealer.id)
          .select('id');
      // Zero rows means the database's update policy on `dealers` didn't match
      // this account. RLS filters silently instead of raising. The app has
      // already confirmed the user is an owner, so the cause is server-side.
      if (rows.isEmpty) {
        debugPrint('Dealership settings: UPDATE matched 0 rows for dealer '
            '${widget.dealer.id} — dealers update RLS policy did not match.');
        throw 'Settings were not saved: the database rejected the update for this '
            'account. Apply migration 20261014160000_dealers_owner_update_policy.sql '
            'in Supabase, then try again.';
      }
      ref.invalidate(currentDealershipProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Dealership settings saved')));
    } on PostgrestException catch (e) {
      debugPrint('Dealership settings: ${e.code} ${e.message} details=${e.details}');
      messenger.showSnackBar(SnackBar(
          content: Text('Could not save: ${e.message}'), backgroundColor: p.error));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e'), backgroundColor: p.error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    String? required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          border: Border.all(color: p.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.canEdit)
              Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.paddingM),
                child: Text('Only the dealership owner can edit these settings.',
                    style: AppTextStyles.caption.copyWith(color: p.textSecondary)),
              ),
            _field(p, _name, 'Showroom name', validator: required),
            _field(p, _phone, 'Phone / WhatsApp number',
                hint: 'e.g. 0300 1234567', validator: (v) {
              if (required(v) != null) return 'Required';
              return ContactLinks.internationalDigits(v) == null
                  ? 'Enter a valid phone number'
                  : null;
            }),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _field(p, _city, 'City', validator: required)),
              const SizedBox(width: AppDimensions.paddingM),
              Expanded(flex: 2, child: _field(p, _address, 'Address')),
            ]),
            _field(p, _hours, 'Business hours',
                hint: 'e.g. Mon–Sat 10am–8pm, Sun closed', maxLength: 200),
            const SizedBox(height: AppDimensions.paddingS),
            if (widget.canEdit)
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: p.onAccent))
                      : const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Save changes'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: p.accent, foregroundColor: p.onAccent),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _field(AppPalette p, TextEditingController c, String label,
      {String? hint, int? maxLength, String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.paddingM),
      child: TextFormField(
        controller: c,
        enabled: widget.canEdit && !_saving,
        maxLength: maxLength,
        validator: validator,
        style: AppTextStyles.body.copyWith(color: p.textPrimary, fontSize: 13.5),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          counterText: '',
          filled: true,
          fillColor: p.surface,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
              borderSide: BorderSide(color: p.border)),
        ),
      ),
    );
  }
}

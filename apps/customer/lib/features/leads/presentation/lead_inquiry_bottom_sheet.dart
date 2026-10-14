// lib/features/leads/presentation/lead_inquiry_bottom_sheet.dart
//
// One sheet for both "Book Test Drive" (swipe-up on the deck, or the detail
// screen's action bar) and "Send Inquiry". Name/phone/email are pre-filled
// from the signed-in customer's `profiles` row + auth email.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../../core/validators.dart';
import '../../auth/providers/auth_providers.dart';
import '../../saved/providers/saved_cars_providers.dart';
import '../providers/lead_providers.dart';
import '../services/lead_service.dart';

Future<void> showLeadInquiryBottomSheet(
  BuildContext context, {
  required CarModel car,
  required LeadType type,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => LeadInquiryBottomSheet(car: car, type: type),
  );
}

class LeadInquiryBottomSheet extends ConsumerStatefulWidget {
  const LeadInquiryBottomSheet({super.key, required this.car, required this.type});
  final CarModel car;
  final LeadType type;

  @override
  ConsumerState<LeadInquiryBottomSheet> createState() => _LeadInquiryBottomSheetState();
}

class _LeadInquiryBottomSheetState extends ConsumerState<LeadInquiryBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _dateFieldKey = GlobalKey<FormFieldState<DateTime>>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  final _messageCtrl = TextEditingController();

  DateTime? _preferredDate;
  bool _success = false;

  bool get _isTestDrive => widget.type == LeadType.testDrive;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(currentProfileProvider);
    _nameCtrl = TextEditingController(text: profile?.fullName ?? '');
    _phoneCtrl = TextEditingController(text: profile?.phone ?? '');
    _emailCtrl = TextEditingController(text: profile?.email ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _preferredDate ?? today.add(const Duration(days: 1)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 180)),
    );
    if (!mounted || picked == null) return;
    setState(() => _preferredDate = picked);
    _dateFieldKey.currentState?.didChange(picked);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final ok = await ref.read(leadSubmissionProvider.notifier).submit(
          type: widget.type,
          car: widget.car,
          fullName: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          message: _messageCtrl.text,
          preferredDate: _preferredDate,
        );
    if (!mounted || !ok) return;

    // Asking about a car is a stronger signal than a right-swipe, so it also
    // counts as saved and won't resurface in the deck.
    await ref.read(savedCarsProvider.notifier).add(widget.car);
    if (!mounted) return;

    setState(() => _success = true);
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(leadSubmissionProvider);
    final p = context.palette;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusL)),
            ),
            padding: const EdgeInsets.fromLTRB(
                AppDimensions.paddingL, AppDimensions.paddingM, AppDimensions.paddingL, AppDimensions.paddingL),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: _success
                  ? _SuccessContent(isTestDrive: _isTestDrive)
                  : SingleChildScrollView(child: _form(state, p)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form(LeadSubmissionState state, AppPalette p) {
    final enabled = !state.isSubmitting;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: AppDimensions.paddingM),
              decoration: BoxDecoration(
                color: p.border,
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              ),
            ),
          ),
          Text(_isTestDrive ? 'Book a test drive' : 'Send an inquiry',
              style: AppTextStyles.heading2.copyWith(color: p.textPrimary)),
          const SizedBox(height: 4),
          Text('${widget.car.displayTitle} · ${widget.car.formattedPrice}',
              style: AppTextStyles.caption.copyWith(color: p.textSecondary)),
          const SizedBox(height: AppDimensions.paddingL),
          TextFormField(
            controller: _nameCtrl,
            enabled: enabled,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            decoration: const InputDecoration(labelText: 'Full name'),
            validator: Validators.fullName,
          ),
          const SizedBox(height: AppDimensions.paddingM),
          TextFormField(
            controller: _phoneCtrl,
            enabled: enabled,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: const InputDecoration(labelText: 'Phone number'),
            validator: Validators.phone,
          ),
          const SizedBox(height: AppDimensions.paddingM),
          TextFormField(
            controller: _emailCtrl,
            enabled: enabled,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Email address'),
            validator: Validators.email,
          ),
          if (_isTestDrive) ...[
            const SizedBox(height: AppDimensions.paddingM),
            FormField<DateTime>(
              key: _dateFieldKey,
              initialValue: _preferredDate,
              validator: (v) => v == null ? 'Pick a preferred date' : null,
              builder: (field) => InkWell(
                onTap: enabled ? _pickDate : null,
                borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Preferred date',
                    errorText: field.errorText,
                    suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                  ),
                  child: Text(
                    _preferredDate == null
                        ? 'Select a date'
                        : LeadService.formatDate(_preferredDate!),
                    style: AppTextStyles.body.copyWith(
                        color: _preferredDate == null ? p.textTertiary : p.textPrimary),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppDimensions.paddingM),
          TextFormField(
            controller: _messageCtrl,
            enabled: enabled,
            minLines: 2,
            maxLines: 4,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Message (optional)',
              hintText: _isTestDrive
                  ? 'e.g. Weekday mornings work best'
                  : 'e.g. Is the price negotiable?',
              alignLabelWithHint: true,
            ),
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: AppDimensions.paddingS),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline_rounded, size: 16, color: p.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(state.errorMessage!,
                      style: AppTextStyles.caption.copyWith(color: p.error)),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppDimensions.paddingL),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: enabled ? _submit : null,
              child: state.isSubmitting
                  ? SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: p.onAccent),
                    )
                  : Text(_isTestDrive ? 'Request test drive' : 'Send inquiry',
                      style: AppTextStyles.button.copyWith(color: p.onAccent)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessContent extends StatelessWidget {
  const _SuccessContent({required this.isTestDrive});
  final bool isTestDrive;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingXL),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 450),
            curve: Curves.elasticOut,
            builder: (context, value, _) => Transform.scale(
              scale: value,
              child: Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: p.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_rounded, color: p.success, size: 40),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingL),
          Text(isTestDrive ? 'Test drive requested' : 'Inquiry sent',
              style: AppTextStyles.heading2.copyWith(color: p.textPrimary),
              textAlign: TextAlign.center),
          const SizedBox(height: AppDimensions.paddingS),
          Text(
            isTestDrive
                ? 'The dealer will contact you to confirm your test drive.'
                : 'The dealer will get back to you shortly.',
            style: AppTextStyles.caption.copyWith(color: p.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

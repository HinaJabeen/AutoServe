// lib/features/discovery/presentation/widgets/book_test_drive_sheet.dart
//
// Swipe-up modal. Collects name, email, phone, and preferred date — see
// `TestDriveRequestNotifier.submit` for why email/date are folded into
// `notes` rather than new `leads` columns (no new schema was asked for).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../providers/discovery_providers.dart';

Future<void> showBookTestDriveSheet(BuildContext context, CarModel car) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BookTestDriveSheet(car: car),
  );
}

class _BookTestDriveSheet extends ConsumerStatefulWidget {
  const _BookTestDriveSheet({required this.car});
  final CarModel car;

  @override
  ConsumerState<_BookTestDriveSheet> createState() => _BookTestDriveSheetState();
}

class _BookTestDriveSheetState extends ConsumerState<_BookTestDriveSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dateFieldKey = GlobalKey<FormFieldState<DateTime>>();

  DateTime? _preferredDate;
  bool _success = false;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _preferredDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
    );
    // Async gap over a Supabase-free dialog, but still a gap — the sheet
    // could have been dismissed (e.g. swipe-to-close) while the date picker
    // was open.
    if (!mounted) return;
    if (picked != null) {
      setState(() => _preferredDate = picked);
      _dateFieldKey.currentState?.didChange(picked);
    }
  }

  Future<void> _submit() async {
    final formOk = _formKey.currentState!.validate();
    // The date picker isn't a FormField by default, so it needs its own
    // explicit check alongside `validate()`.
    if (!formOk || _preferredDate == null) {
      setState(() {}); // surface the date field's validator message
      return;
    }

    final ok = await ref.read(testDriveRequestProvider.notifier).submit(
          car: widget.car,
          customerName: _nameCtrl.text.trim(),
          customerEmail: _emailCtrl.text.trim(),
          customerPhone: _phoneCtrl.text.trim(),
          preferredDate: _preferredDate!,
        );

    if (!mounted) return;
    if (!ok) return;

    await ref.read(localSwipeStoreProvider).markInterested(widget.car.id);
    ref.read(savedCarsProvider.notifier).add(widget.car);
    if (!mounted) return;

    setState(() => _success = true);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(testDriveRequestProvider);
    final p = context.palette;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
          child: _success ? const _SuccessContent() : _form(state, p),
        ),
      ),
    );
  }

  Widget _form(TestDriveRequestState state, AppPalette p) {
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
          Text('Book a test drive', style: AppTextStyles.heading2.copyWith(color: p.textPrimary)),
          const SizedBox(height: 4),
          Text(widget.car.displayTitle, style: AppTextStyles.caption.copyWith(color: p.textSecondary)),
          const SizedBox(height: AppDimensions.paddingL),
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Your name'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: AppDimensions.paddingM),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email address'),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return 'Required';
              if (!_emailPattern.hasMatch(value)) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: AppDimensions.paddingM),
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone number'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: AppDimensions.paddingM),
          FormField<DateTime>(
            key: _dateFieldKey,
            initialValue: _preferredDate,
            validator: (v) => v == null ? 'Pick a preferred date' : null,
            builder: (field) => InkWell(
              onTap: _pickDate,
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
                      : '${_preferredDate!.day}/${_preferredDate!.month}/${_preferredDate!.year}',
                  style: AppTextStyles.body.copyWith(color: p.textPrimary),
                ),
              ),
            ),
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: AppDimensions.paddingS),
            Text(state.errorMessage!,
                style: AppTextStyles.caption.copyWith(color: p.error)),
          ],
          const SizedBox(height: AppDimensions.paddingL),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: state.isSubmitting ? null : _submit,
              child: state.isSubmitting
                  ? SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: p.onAccent),
                    )
                  : Text('Request test drive', style: AppTextStyles.button.copyWith(color: p.onAccent)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessContent extends StatelessWidget {
  const _SuccessContent();

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
            builder: (context, value, child) => Transform.scale(
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
          Text('Request sent',
              style: AppTextStyles.heading2.copyWith(color: p.textPrimary),
              textAlign: TextAlign.center),
          const SizedBox(height: AppDimensions.paddingS),
          Text(
            'The dealer will contact you to confirm your test drive.',
            style: AppTextStyles.caption.copyWith(color: p.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

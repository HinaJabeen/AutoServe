// apps/dashboard/lib/features/presentation/add_vehicle_form.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import 'package:dashboard/features/providers/vehicle_provider.dart';

// ── Dropdown value sets — MUST match DB check constraints exactly ─────────────
//
// 0005_ops_enrichment.sql:
//   condition  CHECK: 'excellent','good','fair'       ← was wrong ('new','used','certified')
//   fuel_type  CHECK: 'petrol','diesel','hybrid','electric','cng'
//   transmission CHECK: 'manual','automatic'
//
// 0001_init.sql:
//   (no body_type constraint — free text stored in specs jsonb)

const _conditions    = ['excellent', 'good', 'fair'];
const _fuelTypes     = ['petrol', 'diesel', 'hybrid', 'electric', 'cng'];
const _transmissions = ['manual', 'automatic'];
const _bodyTypes     = ['sedan', 'suv', 'hatchback', 'pickup', 'van', 'coupe', 'convertible'];

String _titleCase(String s) {
  if (s.isEmpty) return s;
  if (s == 'suv') return 'SUV';
  if (s == 'cng') return 'CNG';
  return s[0].toUpperCase() + s.substring(1);
}

// Safely maps a raw DB value to a valid dropdown value.
// If the value isn't in the allowed list, returns null so the dropdown
// shows empty rather than crashing with an assertion error.
String? _safeValue(String? raw, List<String> allowed) =>
    (raw != null && allowed.contains(raw)) ? raw : null;

class AddVehicleForm extends ConsumerStatefulWidget {
  const AddVehicleForm({super.key, this.vehicleToEdit});
  final VehicleModel? vehicleToEdit;

  @override
  ConsumerState<AddVehicleForm> createState() => _AddVehicleFormState();
}

class _AddVehicleFormState extends ConsumerState<AddVehicleForm> {
  final _formKey = GlobalKey<FormState>();

  late final _makeCtrl        = TextEditingController(text: widget.vehicleToEdit?.make ?? '');
  late final _modelCtrl       = TextEditingController(text: widget.vehicleToEdit?.model ?? '');
  late final _yearCtrl        = TextEditingController(text: widget.vehicleToEdit?.year.toString() ?? '');
  late final _colorCtrl       = TextEditingController(text: widget.vehicleToEdit?.color ?? '');
  late final _mileageCtrl     = TextEditingController(text: widget.vehicleToEdit?.mileage.toString() ?? '');
  late final _priceCtrl       = TextEditingController(
    text: widget.vehicleToEdit != null
        ? (widget.vehicleToEdit!.price % 1 == 0
            ? widget.vehicleToEdit!.price.toStringAsFixed(0)
            : widget.vehicleToEdit!.price.toString())
        : '',
  );
  late final _descriptionCtrl = TextEditingController(text: widget.vehicleToEdit?.description ?? '');

  // BUG FIX 1: use _safeValue() so a DB value not in the list → null
  // instead of crashing the DropdownButtonFormField assertion.
  String? _condition;
  String? _fuelType;
  String? _transmission;
  String? _bodyType;
  bool _submitted = false;

  bool get _isEditMode => widget.vehicleToEdit != null;

  @override
  void initState() {
    super.initState();
    _condition    = _safeValue(widget.vehicleToEdit?.condition,    _conditions);
    _fuelType     = _safeValue(widget.vehicleToEdit?.fuelType,     _fuelTypes);
    _transmission = _safeValue(widget.vehicleToEdit?.transmission, _transmissions);
    _bodyType     = _safeValue(widget.vehicleToEdit?.bodyType,     _bodyTypes);
  }

  @override
  void dispose() {
    _makeCtrl.dispose(); _modelCtrl.dispose(); _yearCtrl.dispose();
    _colorCtrl.dispose(); _mileageCtrl.dispose(); _priceCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;
    if (_condition == null || _fuelType == null ||
        _transmission == null || _bodyType == null) {
      setState(() {});
      return;
    }

    ref.read(vehicleNotifierProvider.notifier).clearError();

    final notifier = ref.read(vehicleNotifierProvider.notifier);
    final success = _isEditMode
        ? await notifier.updateVehicle(
            id:           widget.vehicleToEdit!.id,
            make:         _makeCtrl.text,
            model:        _modelCtrl.text,
            year:         int.parse(_yearCtrl.text),
            color:        _colorCtrl.text,
            mileage:      int.parse(_mileageCtrl.text),
            price:        double.parse(_priceCtrl.text),
            condition:    _condition!,
            fuelType:     _fuelType!,
            transmission: _transmission!,
            bodyType:     _bodyType!,
            description:  _descriptionCtrl.text,
          )
        : await notifier.addVehicle(
            make:         _makeCtrl.text,
            model:        _modelCtrl.text,
            year:         int.parse(_yearCtrl.text),
            color:        _colorCtrl.text,
            mileage:      int.parse(_mileageCtrl.text),
            price:        double.parse(_priceCtrl.text),
            condition:    _condition!,
            fuelType:     _fuelType!,
            transmission: _transmission!,
            bodyType:     _bodyType!,
            description:  _descriptionCtrl.text,
          );

    if (success && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final mutationState = ref.watch(vehicleNotifierProvider);
    final isSubmitting  = mutationState.isSubmitting;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 680,
        constraints: const BoxConstraints(maxHeight: 700),
        decoration: BoxDecoration(
          color: AppColors.navySurface.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          border: Border.all(color: AppColors.navyBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.paddingL, AppDimensions.paddingL,
                AppDimensions.paddingM, AppDimensions.paddingM,
              ),
              child: Row(children: [
                Expanded(
                  child: Text(
                    _isEditMode ? 'Edit Vehicle' : 'Add New Vehicle',
                    style: AppTextStyles.heading2.copyWith(
                        color: Colors.white, fontSize: 19),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white38, size: 20),
                  onPressed: isSubmitting
                      ? null : () => Navigator.of(context).pop(false),
                ),
              ]),
            ),
            Divider(color: AppColors.navyBorder.withValues(alpha: 0.6), height: 1),

            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.paddingL),
                child: Form(
                  key: _formKey,
                  autovalidateMode: _submitted
                      ? AutovalidateMode.onUserInteraction
                      : AutovalidateMode.disabled,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _row([
                        _textField(_makeCtrl, 'Make',
                            validator: _required),
                        _textField(_modelCtrl, 'Model',
                            validator: _required),
                      ]),
                      _row([
                        _textField(_yearCtrl, 'Year',
                            type: TextInputType.number,
                            validator: (v) {
                              final y = int.tryParse(v ?? '');
                              if (y == null) return 'Enter a valid year';
                              if (y < 1980 || y > 2030) return '1980–2030';
                              return null;
                            }),
                        _textField(_colorCtrl, 'Color',
                            validator: _required),
                      ]),
                      _row([
                        _textField(_mileageCtrl, 'Mileage (km)',
                            type: TextInputType.number,
                            validator: (v) {
                              final m = int.tryParse(v ?? '');
                              if (m == null) return 'Enter a number';
                              if (m < 0) return 'Must be ≥ 0';
                              return null;
                            }),
                        _textField(_priceCtrl, 'Price (PKR)',
                            type: const TextInputType.numberWithOptions(decimal: true),
                            validator: (v) {
                              final p = double.tryParse(v ?? '');
                              if (p == null) return 'Enter a price';
                              if (p <= 0) return 'Must be > 0';
                              return null;
                            }),
                      ]),
                      _row([
                        _dropdown('Condition', _condition, _conditions,
                            (v) => setState(() => _condition = v)),
                        _dropdown('Fuel Type', _fuelType, _fuelTypes,
                            (v) => setState(() => _fuelType = v)),
                      ]),
                      _row([
                        _dropdown('Transmission', _transmission, _transmissions,
                            (v) => setState(() => _transmission = v)),
                        _dropdown('Body Type', _bodyType, _bodyTypes,
                            (v) => setState(() => _bodyType = v)),
                      ]),
                      _textField(_descriptionCtrl, 'Description',
                          maxLines: 4, validator: _required),

                      if (mutationState.errorMessage != null) ...[
                        const SizedBox(height: AppDimensions.paddingM),
                        Container(
                          padding: const EdgeInsets.all(AppDimensions.paddingM),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.08),
                            borderRadius:
                                BorderRadius.circular(AppDimensions.radiusS),
                            border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.3)),
                          ),
                          child: Text(mutationState.errorMessage!,
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.error)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            Divider(color: AppColors.navyBorder.withValues(alpha: 0.6), height: 1),

            // Footer
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: isSubmitting
                        ? null : () => Navigator.of(context).pop(false),
                    child: Text('Cancel',
                        style: AppTextStyles.body
                            .copyWith(color: Colors.white54)),
                  ),
                  const SizedBox(width: AppDimensions.paddingS),
                  SizedBox(
                    height: 42,
                    child: ElevatedButton(
                      onPressed: isSubmitting ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.ambientBlue,
                        foregroundColor: AppColors.navyBackground,
                        disabledBackgroundColor:
                            AppColors.ambientBlue.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppDimensions.radiusS)),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.navyBackground))
                          : Text(
                              _isEditMode ? 'Save Changes' : 'Add Vehicle',
                              style: AppTextStyles.button.copyWith(
                                  color: AppColors.navyBackground,
                                  fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  Widget _row(List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: AppDimensions.paddingM),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children.expand((w) sync* {
        yield Expanded(child: w);
        if (w != children.last) {
          yield const SizedBox(width: AppDimensions.paddingM);
        }
      }).toList(),
    ),
  );

  Widget _textField(
    TextEditingController ctrl,
    String label, {
    TextInputType? type,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          const SizedBox(height: 6),
          TextFormField(
            controller: ctrl,
            keyboardType: type,
            maxLines: maxLines,
            validator: validator,
            style: AppTextStyles.body
                .copyWith(color: Colors.white, fontSize: 13),
            decoration: _dec(),
          ),
        ],
      );

  Widget _dropdown(
    String label,
    String? value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: value,  // safe — guaranteed null or in list
            isExpanded: true,
            dropdownColor: AppColors.navySurface,
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.white38, size: 18),
            style: AppTextStyles.body
                .copyWith(color: Colors.white, fontSize: 13),
            validator: (v) => v == null ? 'Required' : null,
            decoration: _dec(),
            items: items
                .map((i) => DropdownMenuItem(
                    value: i, child: Text(_titleCase(i))))
                .toList(),
            onChanged: onChanged,
          ),
        ],
      );

  Widget _label(String text) => Text(
    text,
    style: AppTextStyles.caption.copyWith(
        color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w500),
  );

  InputDecoration _dec() => InputDecoration(
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.04),
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        borderSide: BorderSide(color: AppColors.navyBorder)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        borderSide: BorderSide(color: AppColors.navyBorder)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        borderSide:
            const BorderSide(color: AppColors.ambientBlue, width: 1.4)),
    errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        borderSide:
            BorderSide(color: AppColors.error.withValues(alpha: 0.6))),
    focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        borderSide: const BorderSide(color: AppColors.error)),
    errorStyle: AppTextStyles.caption
        .copyWith(color: AppColors.error, fontSize: 11),
  );
}
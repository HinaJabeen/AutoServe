// lib/features/inventory/presentation/vehicle_form_v2.dart
//
// NOTE ON DROPDOWNS: values here match the actual DB check constraints in
// 0005_ops_enrichment.sql, not the old add_vehicle_form.dart values — that
// mismatch (condition: 'new'/'used'/'certified' vs DB's 'excellent'/'good'/
// 'fair') is the likely root cause of the dropdown assertion bug you hit
// earlier. `body_type` has no column in the schema at all, so it's stored
// inside `specs` jsonb here rather than invented as a fake column.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared/shared.dart';

import 'package:dashboard/features/inventory/providers/vehicle_form_provider.dart';
import 'package:dashboard/features/inventory/providers/inventory_providers.dart';

const _statuses = ['available', 'reserved', 'sold'];
const _conditions = ['excellent', 'good', 'fair'];
const _fuelTypes = ['petrol', 'diesel', 'hybrid', 'electric', 'cng'];
const _transmissions = ['manual', 'automatic'];

String _titleCase(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) return newValue.copyWith(text: '');
    final formatted = digitsOnly.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}

/// Rejects negative numbers at the input level, in addition to the
/// validator — belt and suspenders against negative price/mileage.
class _NonNegativeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.contains('-')) return oldValue;
    return newValue;
  }
}

class VehicleFormV2 extends ConsumerStatefulWidget {
  const VehicleFormV2({super.key, this.carToEdit});
  final CarModel? carToEdit;

  @override
  ConsumerState<VehicleFormV2> createState() => _VehicleFormV2State();
}

class _VehicleFormV2State extends ConsumerState<VehicleFormV2> {
  final _formKey = GlobalKey<FormState>();

  late final _vinCtrl = TextEditingController();
  late final _makeCtrl = TextEditingController(text: widget.carToEdit?.make ?? '');
  late final _modelCtrl = TextEditingController(text: widget.carToEdit?.model ?? '');
  late final _yearCtrl = TextEditingController(text: widget.carToEdit?.year.toString() ?? '');
  late final _colorCtrl = TextEditingController(text: widget.carToEdit?.color ?? '');
  late final _mileageCtrl = TextEditingController(text: _thousands(widget.carToEdit?.mileage));
  late final _priceCtrl = TextEditingController(text: _thousands(widget.carToEdit?.price.toInt()));
  late final _purchasePriceCtrl = TextEditingController(text: _thousands(widget.carToEdit?.purchasePrice?.toInt()));
  late final _retailPriceCtrl = TextEditingController(text: _thousands(widget.carToEdit?.retailPrice?.toInt()));
  late final _featuresCtrl = TextEditingController(text: widget.carToEdit?.features.join(', ') ?? '');
  late final _notesCtrl = TextEditingController(text: widget.carToEdit?.reconditioningNotes ?? '');
  late final _descriptionCtrl = TextEditingController(text: widget.carToEdit?.description ?? '');

  String? _status;
  String? _condition;
  String? _fuelType;
  String? _transmission;
  bool _isPublic = true;
  bool _submitted = false;
  final List<XFile> _pendingPhotos = [];

  bool get _isEditMode => widget.carToEdit != null;

  static String _thousands(int? v) {
    if (v == null) return '';
    return v.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  static double? _parseThousands(String s) {
    final clean = s.replaceAll(',', '').trim();
    return clean.isEmpty ? null : double.tryParse(clean);
  }

  @override
  void initState() {
    super.initState();
    _status = widget.carToEdit?.status ?? 'available';
    _condition = widget.carToEdit?.condition;
    _fuelType = widget.carToEdit?.fuelType;
    _transmission = widget.carToEdit?.transmission;
    _isPublic = widget.carToEdit?.isPublic ?? true;
  }

  @override
  void dispose() {
    for (final c in [_vinCtrl, _makeCtrl, _modelCtrl, _yearCtrl, _colorCtrl, _mileageCtrl, _priceCtrl, _purchasePriceCtrl, _retailPriceCtrl, _featuresCtrl, _notesCtrl, _descriptionCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _decodeVin() async {
    final vin = _vinCtrl.text.trim();
    final notifier = ref.read(vehicleFormProvider.notifier);
    if (!notifier.isValidVin(vin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('VIN must be exactly 17 characters (no I, O, or Q).')),
      );
      return;
    }
    final decoded = await notifier.decodeVin(vin);
    if (decoded == null) {
      final err = ref.read(vehicleFormProvider).errorMessage;
      if (err != null && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    setState(() {
      if (decoded.make != null) _makeCtrl.text = decoded.make!;
      if (decoded.model != null) _modelCtrl.text = decoded.model!;
      if (decoded.year != null) _yearCtrl.text = decoded.year.toString();
      if (decoded.transmission != null) {
        final t = decoded.transmission!.toLowerCase();
        _transmission = t.contains('manual') ? 'manual' : (t.contains('auto') ? 'automatic' : _transmission);
      }
      if (decoded.fuelType != null) {
        final f = decoded.fuelType!.toLowerCase();
        _fuelType = _fuelTypes.firstWhere((e) => f.contains(e), orElse: () => _fuelType ?? '');
        if (_fuelType!.isEmpty) _fuelType = null;
      }
    });
  }

  Future<void> _pickPhotos() async {
    final storage = ref.read(vehicleStorageServiceProvider);
    if (storage == null) return;
    final files = await storage.pickImages();
    setState(() => _pendingPhotos.addAll(files));
  }

  Future<void> _handleSubmit() async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;
    if (_status == null || _condition == null || _fuelType == null || _transmission == null) {
      setState(() {});
      return;
    }

    final notifier = ref.read(vehicleFormProvider.notifier);
    notifier.clearError();

    final now = DateTime.now();
    final features = _featuresCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    final car = CarModel(
      id: widget.carToEdit?.id ?? '',
      dealerId: widget.carToEdit?.dealerId ?? '',
      make: _makeCtrl.text.trim(),
      model: _modelCtrl.text.trim(),
      year: int.parse(_yearCtrl.text.trim()),
      price: _parseThousands(_priceCtrl.text)!,
      status: _status!,
      createdAt: widget.carToEdit?.createdAt ?? now,
      updatedAt: now,
      mileage: _parseThousands(_mileageCtrl.text)?.toInt(),
      color: _colorCtrl.text.trim().isEmpty ? null : _colorCtrl.text.trim(),
      transmission: _transmission,
      fuelType: _fuelType,
      condition: _condition,
      purchasePrice: _parseThousands(_purchasePriceCtrl.text),
      retailPrice: _parseThousands(_retailPriceCtrl.text),
      isPublic: _isPublic,
      features: features,
      reconditioningNotes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      // Null fields are dropped from the payload, so clearing an existing
      // description has to send '' to actually overwrite it.
      description: _descriptionCtrl.text.trim().isNotEmpty
          ? _descriptionCtrl.text.trim()
          : (widget.carToEdit?.description != null ? '' : null),
    );

    final result = _isEditMode
        ? await notifier.updateCar(widget.carToEdit!.id, car)
        : await notifier.createCar(car);

    if (result == null) return;

    // The vehicle row exists at this point, so the dialog closes either way
    // (staying open would make a retry create a duplicate car); an upload
    // failure is reported on the page underneath instead.
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = context.palette.error;
    final uploadError = _pendingPhotos.isEmpty
        ? null
        : await notifier.uploadPhotos(result.id, _pendingPhotos);

    if (mounted) Navigator.of(context).pop(true);
    if (uploadError != null) {
      messenger.showSnackBar(SnackBar(
        content: Text('Vehicle saved, but photos failed: $uploadError'),
        backgroundColor: errorColor,
        duration: const Duration(seconds: 10),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(vehicleFormProvider);
    final busy = formState.isSubmitting || formState.isUploadingPhotos;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 720,
        constraints: const BoxConstraints(maxHeight: 780),
        decoration: BoxDecoration(
          color: context.palette.card,
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          border: Border.all(color: context.palette.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(_isEditMode ? 'Edit Vehicle' : 'Add New Vehicle',
                        style: AppTextStyles.heading2.copyWith(color: context.palette.textPrimary, fontSize: 19)),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: context.palette.textTertiary, size: 20),
                    onPressed: busy ? null : () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),
            Divider(color: context.palette.border, height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.paddingL),
                child: Form(
                  key: _formKey,
                  autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!_isEditMode) ...[
                        Row(
                          children: [
                            Expanded(
                              child: _textField(
                                controller: _vinCtrl,
                                label: 'VIN (optional — auto-fills make/model/year)',
                                maxLength: 17,
                                validator: (v) => (v != null && v.isNotEmpty && v.length != 17) ? 'Must be 17 characters' : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              height: 44,
                              child: ElevatedButton(
                                onPressed: formState.isDecodingVin ? null : _decodeVin,
                                style: ElevatedButton.styleFrom(backgroundColor: context.palette.accent, foregroundColor: context.palette.onAccent),
                                child: formState.isDecodingVin
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Text('Decode'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.paddingM),
                      ],
                      Row(children: [
                        Expanded(child: _textField(controller: _makeCtrl, label: 'Make', validator: _required)),
                        const SizedBox(width: 12),
                        Expanded(child: _textField(controller: _modelCtrl, label: 'Model', validator: _required)),
                      ]),
                      const SizedBox(height: AppDimensions.paddingM),
                      Row(children: [
                        Expanded(
                          child: _textField(
                            controller: _yearCtrl,
                            label: 'Year',
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (v) {
                              final year = int.tryParse(v ?? '');
                              if (year == null) return 'Enter a valid year';
                              if (year < 1980 || year > 2030) return '1980–2030 only';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: _textField(controller: _colorCtrl, label: 'Color')),
                      ]),
                      const SizedBox(height: AppDimensions.paddingM),
                      Row(children: [
                        Expanded(
                          child: _textField(
                            controller: _mileageCtrl,
                            label: 'Mileage (km)',
                            keyboardType: TextInputType.number,
                            inputFormatters: [_NonNegativeFormatter(), _ThousandsFormatter()],
                            validator: (v) {
                              final m = _parseThousands(v ?? '');
                              if (m == null) return 'Enter a valid number';
                              if (m < 0) return 'Must be 0 or more';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _textField(
                            controller: _priceCtrl,
                            label: 'Sale Price (PKR)',
                            keyboardType: TextInputType.number,
                            inputFormatters: [_NonNegativeFormatter(), _ThousandsFormatter()],
                            validator: (v) {
                              final p = _parseThousands(v ?? '');
                              if (p == null) return 'Enter a valid price';
                              if (p <= 0) return 'Must be greater than 0';
                              return null;
                            },
                          ),
                        ),
                      ]),
                      const SizedBox(height: AppDimensions.paddingM),
                      Row(children: [
                        Expanded(
                          child: _textField(
                            controller: _purchasePriceCtrl,
                            label: 'Purchase Price — staff only (PKR)',
                            keyboardType: TextInputType.number,
                            inputFormatters: [_NonNegativeFormatter(), _ThousandsFormatter()],
                            validator: (v) {
                              if (v == null || v.isEmpty) return null;
                              final p = _parseThousands(v);
                              if (p != null && p < 0) return 'Cannot be negative';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _textField(
                            controller: _retailPriceCtrl,
                            label: 'Listed Retail Price (PKR)',
                            keyboardType: TextInputType.number,
                            inputFormatters: [_NonNegativeFormatter(), _ThousandsFormatter()],
                            validator: (v) {
                              if (v == null || v.isEmpty) return null;
                              final p = _parseThousands(v);
                              if (p != null && p < 0) return 'Cannot be negative';
                              return null;
                            },
                          ),
                        ),
                      ]),
                      const SizedBox(height: AppDimensions.paddingM),
                      Row(children: [
                        Expanded(child: _dropdown('Status', _status, _statuses, (v) => setState(() => _status = v))),
                        const SizedBox(width: 12),
                        Expanded(child: _dropdown('Condition', _condition, _conditions, (v) => setState(() => _condition = v))),
                      ]),
                      const SizedBox(height: AppDimensions.paddingM),
                      Row(children: [
                        Expanded(child: _dropdown('Fuel Type', _fuelType, _fuelTypes, (v) => setState(() => _fuelType = v))),
                        const SizedBox(width: 12),
                        Expanded(child: _dropdown('Transmission', _transmission, _transmissions, (v) => setState(() => _transmission = v))),
                      ]),
                      const SizedBox(height: AppDimensions.paddingM),
                      _textField(controller: _featuresCtrl, label: 'Features (comma-separated)'),
                      const SizedBox(height: AppDimensions.paddingM),
                      _textField(controller: _descriptionCtrl, label: 'Description (shown to customers)', maxLines: 4, maxLength: 2000),
                      const SizedBox(height: AppDimensions.paddingM),
                      _textField(controller: _notesCtrl, label: 'Reconditioning Notes (internal)', maxLines: 3),
                      const SizedBox(height: AppDimensions.paddingM),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _isPublic,
                        onChanged: (v) => setState(() => _isPublic = v),
                        activeThumbColor: context.palette.accent,
                        title: Text('Visible in customer app', style: AppTextStyles.body.copyWith(color: context.palette.textPrimary, fontSize: 13)),
                      ),
                      const SizedBox(height: AppDimensions.paddingM),
                      OutlinedButton.icon(
                        onPressed: _pickPhotos,
                        icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                        label: Text('Add Photos (${_pendingPhotos.length} selected)'),
                        style: OutlinedButton.styleFrom(side: BorderSide(color: context.palette.border)),
                      ),
                      if (formState.errorMessage != null) ...[
                        const SizedBox(height: AppDimensions.paddingM),
                        Container(
                          padding: const EdgeInsets.all(AppDimensions.paddingM),
                          decoration: BoxDecoration(
                            color: context.palette.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                            border: Border.all(color: context.palette.error.withValues(alpha: 0.3)),
                          ),
                          child: Text(formState.errorMessage!, style: AppTextStyles.caption.copyWith(color: context.palette.error)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Divider(color: context.palette.border, height: 1),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 42,
                    child: ElevatedButton(
                      onPressed: busy ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(backgroundColor: context.palette.accent, foregroundColor: context.palette.onAccent),
                      child: busy
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_isEditMode ? 'Save Changes' : 'Add Vehicle'),
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

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  Widget _textField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption.copyWith(color: context.palette.textSecondary, fontSize: 11)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          validator: validator,
          style: AppTextStyles.body.copyWith(color: context.palette.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: context.palette.surface,
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusS), borderSide: BorderSide(color: context.palette.border)),
          ),
        ),
      ],
    );
  }

  Widget _dropdown(String label, String? value, List<String> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption.copyWith(color: context.palette.textSecondary, fontSize: 11)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          // `initialValue` is guaranteed to be either null or a member of
          // `items` (both draw from the same schema-matched constant lists),
          // which is what avoids the dropdown assertion error from before.
          initialValue: value != null && items.contains(value) ? value : null,
          isExpanded: true,
          dropdownColor: context.palette.card,
          style: AppTextStyles.body.copyWith(color: context.palette.textPrimary, fontSize: 13),
          validator: (v) => v == null ? 'Required' : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: context.palette.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusS), borderSide: BorderSide(color: context.palette.border)),
          ),
          items: items.map((item) => DropdownMenuItem(value: item, child: Text(_titleCase(item)))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
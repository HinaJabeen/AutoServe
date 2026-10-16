// lib/features/dealer_application/presentation/become_dealer_screen.dart
//
// /become-dealer — four-step dealership application. Documents upload as
// soon as they're picked (per-slot progress), then one
// submit_dealer_application() call writes the application atomically.
// Re-opened after a rejection, it's pre-filled for "Update & Resubmit".

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared/shared.dart';

import '../../../core/cnic.dart';
import '../../../core/validators.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/dealer_application.dart';
import '../providers/dealer_application_providers.dart';
import '../services/dealer_application_service.dart';

const _kMaxWidth = 560.0;

class _DocSlot {
  const _DocSlot(this.key, this.label, this.hint, this.bucket, this.icon);
  final String key;
  final String label;
  final String hint;
  final UploadBucket bucket;
  final IconData icon;
}

const _slots = [
  _DocSlot('showroom', 'Showroom exterior photo',
      'Front facade with the signboard clearly visible', UploadBucket.showroomPhotos,
      Icons.storefront_outlined),
  _DocSlot('cnic_front', 'Owner CNIC — front', 'All four corners visible, no glare',
      UploadBucket.verificationDocs, Icons.badge_outlined),
  _DocSlot('cnic_back', 'Owner CNIC — back', 'All four corners visible, no glare',
      UploadBucket.verificationDocs, Icons.badge_outlined),
  _DocSlot('business_doc', 'Business proof',
      'Utility bill, showroom lease, or registration certificate',
      UploadBucket.verificationDocs, Icons.description_outlined),
];

class _Upload {
  const _Upload({this.path, this.bytes, this.uploading = false, this.error});
  final String? path;
  final Uint8List? bytes;
  final bool uploading;
  final String? error;
}

class BecomeDealerScreen extends ConsumerWidget {
  const BecomeDealerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final existing = ref.watch(myDealerApplicationProvider);
    return existing.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Register dealership')),
        body: Center(child: Text('$e')),
      ),
      data: (app) {
        if (app != null &&
            app.status != ApplicationStatus.rejected &&
            app.status != ApplicationStatus.pending) {
          return Scaffold(
            appBar: AppBar(title: const Text('Register dealership')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingXL),
                child: Text('Your dealership application is already ${app.status.name}.',
                    textAlign: TextAlign.center),
              ),
            ),
          );
        }
        return _Wizard(existing: app);
      },
    );
  }
}

class _Wizard extends ConsumerStatefulWidget {
  const _Wizard({this.existing});
  final DealerApplication? existing;

  @override
  ConsumerState<_Wizard> createState() => _WizardState();
}

class _WizardState extends ConsumerState<_Wizard> {
  static const _titles = ['Owner identity', 'Showroom details', 'Documents', 'Inventory'];

  final _formKeys = List.generate(4, (_) => GlobalKey<FormState>());
  int _step = 0;
  bool _submitting = false;
  String? _error;

  // Step 1
  late final _ownerName = TextEditingController(text: _e?.ownerFullName ?? _profileName);
  late final _cnic = TextEditingController(text: _e?.ownerCnic ?? '');
  late final _ownerPhone = TextEditingController(text: _e?.ownerPhone ?? _profilePhone);
  // Step 2
  late final _showroomName = TextEditingController(text: _e?.showroomName ?? '');
  late String? _city = _e?.city;
  late final _address = TextEditingController(text: _e?.address ?? '');
  late final _whatsapp = TextEditingController(text: _e?.whatsapp ?? '');
  late final _hours = TextEditingController(
      text: _e?.businessHours ?? 'Mon-Sat: 10:00 AM - 8:00 PM');
  late final _ntn = TextEditingController(text: _e?.ntnNumber ?? '');
  // Step 3
  late final Map<String, _Upload> _uploads = {
    'showroom': _Upload(path: _e?.showroomPhotoPath),
    'cnic_front': _Upload(path: _e?.cnicFrontPath),
    'cnic_back': _Upload(path: _e?.cnicBackPath),
    'business_doc': _Upload(path: _e?.businessDocPath),
  };
  // Step 4
  late String? _stock = _e?.inventoryInfo['expected_stock_size'] as String?;
  late final Set<String> _makes = {
    ...((_e?.inventoryInfo['primary_makes'] as List?)?.map((m) => m.toString()) ?? const <String>[]),
  };
  late final Map<String, dynamic> _sample = Map<String, dynamic>.from(
      (_e?.inventoryInfo['sample_vehicle'] as Map?) ?? const {});
  late final _sampleMake = TextEditingController(text: _sample['make']?.toString() ?? '');
  late final _sampleModel = TextEditingController(text: _sample['model']?.toString() ?? '');
  late final _sampleYear = TextEditingController(text: _sample['year']?.toString() ?? '');
  late final _samplePrice = TextEditingController(text: _sample['price']?.toString() ?? '');

  DealerApplication? get _e => widget.existing;
  String get _profileName => ref.read(currentProfileProvider)?.fullName ?? '';
  String get _profilePhone => ref.read(currentProfileProvider)?.phone ?? '';

  List<TextEditingController> get _controllers => [
        _ownerName, _cnic, _ownerPhone, _showroomName, _address, _whatsapp, _hours, _ntn,
        _sampleMake, _sampleModel, _sampleYear, _samplePrice,
      ];

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Validation ─────────────────────────────────────────────────────────

  static String? _phoneValidator(String? v) =>
      Validators.phone(v) ?? (ContactLinks.internationalDigits(v) == null
          ? 'Enter a valid Pakistani number, e.g. 0300 1234567'
          : null);

  /// "+923001234567" — one stored format regardless of how it was typed.
  static String _normalizePhone(String v) => '+${ContactLinks.internationalDigits(v)}';

  bool _sampleStarted() => [_sampleMake, _sampleModel, _sampleYear, _samplePrice]
      .any((c) => c.text.trim().isNotEmpty);

  bool _validateStep() {
    final formOk = _formKeys[_step].currentState?.validate() ?? true;
    String? extra;
    if (_step == 2) {
      if (_uploads.values.any((u) => u.uploading)) {
        extra = 'Please wait for the uploads to finish.';
      } else if (_uploads.values.any((u) => u.path == null)) {
        extra = 'All four documents are required.';
      }
    } else if (_step == 3) {
      if (_stock == null) {
        extra = 'Choose your expected inventory size.';
      } else if (_makes.isEmpty) {
        extra = 'Pick at least one brand you sell.';
      }
    }
    setState(() => _error = extra);
    return formOk && extra == null;
  }

  void _next() {
    if (!_validateStep()) return;
    if (_step < 3) {
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  void _back() => setState(() {
        _error = null;
        _step--;
      });

  // ── Uploads ────────────────────────────────────────────────────────────

  Future<void> _pick(_DocSlot slot) async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2400,
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    setState(() => _uploads[slot.key] = _Upload(bytes: bytes, uploading: true));
    try {
      final path = await ref.read(dealerApplicationServiceProvider).upload(slot.bucket, slot.key, file);
      if (!mounted) return;
      setState(() => _uploads[slot.key] = _Upload(path: path, bytes: bytes));
    } on DealerApplicationException catch (e) {
      if (!mounted) return;
      setState(() => _uploads[slot.key] = _Upload(error: e.message));
    }
  }

  // ── Submit ─────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final draft = DealerApplicationDraft(
      ownerFullName: _ownerName.text.trim(),
      ownerCnic: _cnic.text.trim(),
      ownerPhone: _normalizePhone(_ownerPhone.text),
      showroomName: _showroomName.text.trim(),
      city: _city!,
      address: _address.text.trim(),
      whatsapp: _normalizePhone(_whatsapp.text),
      businessHours: _hours.text.trim(),
      ntnNumber: _ntn.text.trim(),
      showroomPhotoPath: _uploads['showroom']!.path!,
      cnicFrontPath: _uploads['cnic_front']!.path!,
      cnicBackPath: _uploads['cnic_back']!.path!,
      businessDocPath: _uploads['business_doc']!.path!,
      expectedStock: _stock!,
      primaryMakes: _makes.toList(),
      sampleVehicle: _sampleStarted()
          ? {
              'make': _sampleMake.text.trim(),
              'model': _sampleModel.text.trim(),
              'year': int.parse(_sampleYear.text.trim()),
              'price': int.parse(_samplePrice.text.replaceAll(RegExp(r'\D'), '')),
            }
          : null,
    );
    try {
      await ref.read(dealerApplicationServiceProvider).submit(draft);
      ref.invalidate(myDealerApplicationProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Application submitted — we\'ll review it shortly.')));
      context.pop();
    } on DealerApplicationException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final resubmitting = _e?.status == ApplicationStatus.rejected;

    return PopScope(
      canPop: !_submitting,
      child: Scaffold(
        appBar: AppBar(
          title: Text(resubmitting ? 'Update & resubmit' : 'Register dealership'),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kMaxWidth),
              child: Column(
                children: [
                  _StepHeader(titles: _titles, current: _step),
                  if (resubmitting && _e?.rejectionReason != null)
                    _Banner(
                      color: p.error,
                      icon: Icons.info_outline_rounded,
                      text: 'Previously rejected: ${_e!.rejectionReason}',
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppDimensions.paddingL),
                      child: Form(
                        key: _formKeys[_step],
                        child: switch (_step) {
                          0 => _identityStep(),
                          1 => _showroomStep(p),
                          2 => _documentsStep(p),
                          _ => _inventoryStep(p),
                        },
                      ),
                    ),
                  ),
                  if (_error != null)
                    _Banner(color: p.error, icon: Icons.error_outline_rounded, text: _error!),
                  _NavBar(
                    step: _step,
                    submitting: _submitting,
                    onBack: _step == 0 || _submitting ? null : _back,
                    onNext: _submitting ? null : _next,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _gap() => const SizedBox(height: AppDimensions.paddingM);

  Widget _identityStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepIntro('Tell us who owns the dealership. This must match the owner\'s CNIC.'),
          TextFormField(
            controller: _ownerName,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Full legal name (as on CNIC)'),
            validator: Validators.fullName,
          ),
          _gap(),
          TextFormField(
            controller: _cnic,
            keyboardType: TextInputType.number,
            inputFormatters: [CnicInputFormatter()],
            decoration: const InputDecoration(
                labelText: 'CNIC number', hintText: '12345-1234567-1'),
            validator: validateCnic,
          ),
          _gap(),
          TextFormField(
            controller: _ownerPhone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: 'Owner contact phone', hintText: '0300 1234567 or +92 300 1234567'),
            validator: _phoneValidator,
          ),
        ],
      );

  Widget _showroomStep(AppPalette p) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepIntro('Where customers will find you.'),
          TextFormField(
            controller: _showroomName,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Dealership / showroom name'),
            validator: (v) => (v == null || v.trim().length < 3) ? 'Enter the showroom name' : null,
          ),
          _gap(),
          DropdownButtonFormField<String>(
            initialValue: pakistanCities.contains(_city) ? _city : null,
            decoration: const InputDecoration(labelText: 'City'),
            items: [
              for (final c in pakistanCities) DropdownMenuItem(value: c, child: Text(c)),
            ],
            onChanged: (v) => setState(() => _city = v),
            validator: (v) => v == null ? 'Choose a city' : null,
          ),
          _gap(),
          TextFormField(
            controller: _address,
            minLines: 2,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Full showroom address',
              hintText: 'Shop #, plaza, street, sector / area',
              alignLabelWithHint: true,
            ),
            validator: (v) =>
                (v == null || v.trim().length < 10) ? 'Enter the complete physical address' : null,
          ),
          _gap(),
          TextFormField(
            controller: _whatsapp,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: 'Business WhatsApp number',
                helperText: 'Customers contact you on this number'),
            validator: _phoneValidator,
          ),
          _gap(),
          TextFormField(
            controller: _hours,
            decoration: const InputDecoration(labelText: 'Operating hours'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your opening hours' : null,
          ),
          _gap(),
          TextFormField(
            controller: _ntn,
            decoration: const InputDecoration(
                labelText: 'NTN / business registration no. (optional)'),
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.isEmpty) return null;
              return RegExp(r'^[A-Za-z0-9\-/]{5,30}$').hasMatch(t)
                  ? null
                  : 'Use letters, digits, "-" or "/" (5–30 characters)';
            },
          ),
        ],
      );

  Widget _documentsStep(AppPalette p) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepIntro(
              'These help us confirm your showroom is real. CNIC and business documents '
              'are private — only AutoServe\'s verification team can see them.'),
          for (final slot in _slots) ...[
            _UploadTile(
              slot: slot,
              upload: _uploads[slot.key]!,
              previewUrl: slot.bucket == UploadBucket.showroomPhotos &&
                      _uploads[slot.key]!.bytes == null &&
                      _uploads[slot.key]!.path != null
                  ? ref.read(dealerApplicationServiceProvider).publicUrl(_uploads[slot.key]!.path!)
                  : null,
              onPick: _submitting ? null : () => _pick(slot),
            ),
            _gap(),
          ],
        ],
      );

  Widget _inventoryStep(AppPalette p) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepIntro('Give us a sense of your business size.'),
          Text('Expected inventory size',
              style: AppTextStyles.bodyBold.copyWith(color: p.textPrimary)),
          const SizedBox(height: AppDimensions.paddingS),
          Wrap(
            spacing: AppDimensions.paddingS,
            runSpacing: AppDimensions.paddingS,
            children: [
              for (final o in expectedStockOptions)
                _Choice(
                  label: '$o cars',
                  selected: _stock == o,
                  onTap: () => setState(() => _stock = o),
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingL),
          Text('Primary brands you sell',
              style: AppTextStyles.bodyBold.copyWith(color: p.textPrimary)),
          const SizedBox(height: AppDimensions.paddingS),
          Wrap(
            spacing: AppDimensions.paddingS,
            runSpacing: AppDimensions.paddingS,
            children: [
              for (final b in popularBrands)
                _Choice(
                  label: b,
                  selected: _makes.contains(b),
                  onTap: () => setState(() => _makes.contains(b) ? _makes.remove(b) : _makes.add(b)),
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingL),
          Text('Sample vehicle (optional)',
              style: AppTextStyles.bodyBold.copyWith(color: p.textPrimary)),
          Text('A car you currently have in stock.',
              style: AppTextStyles.caption.copyWith(color: p.textSecondary)),
          const SizedBox(height: AppDimensions.paddingS),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _sampleMake,
                decoration: const InputDecoration(labelText: 'Make'),
                validator: (v) => _sampleStarted() && (v?.trim().isEmpty ?? true) ? 'Required' : null,
              ),
            ),
            const SizedBox(width: AppDimensions.paddingS),
            Expanded(
              child: TextFormField(
                controller: _sampleModel,
                decoration: const InputDecoration(labelText: 'Model'),
                validator: (v) => _sampleStarted() && (v?.trim().isEmpty ?? true) ? 'Required' : null,
              ),
            ),
          ]),
          _gap(),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _sampleYear,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                decoration: const InputDecoration(labelText: 'Year'),
                validator: (v) {
                  if (!_sampleStarted()) return null;
                  final y = int.tryParse(v?.trim() ?? '');
                  return (y == null || y < 1980 || y > DateTime.now().year + 1) ? 'Invalid year' : null;
                },
              ),
            ),
            const SizedBox(width: AppDimensions.paddingS),
            Expanded(
              child: TextFormField(
                controller: _samplePrice,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price (PKR)'),
                validator: (v) {
                  if (!_sampleStarted()) return null;
                  final n = int.tryParse((v ?? '').replaceAll(RegExp(r'\D'), ''));
                  return (n == null || n <= 0) ? 'Invalid price' : null;
                },
              ),
            ),
          ]),
        ],
      );
}

class _StepIntro extends StatelessWidget {
  const _StepIntro(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppDimensions.paddingL),
        child: Text(text,
            style: AppTextStyles.body.copyWith(color: context.palette.textSecondary)),
      );
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.titles, required this.current});
  final List<String> titles;
  final int current;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppDimensions.paddingL, AppDimensions.paddingM, AppDimensions.paddingL, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            for (var i = 0; i < titles.length; i++) ...[
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= current ? p.accent : p.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (i < titles.length - 1) const SizedBox(width: 6),
            ],
          ]),
          const SizedBox(height: AppDimensions.paddingS),
          Text('Step ${current + 1} of ${titles.length} · ${titles[current]}',
              style: AppTextStyles.bodyBold.copyWith(color: p.textPrimary)),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.icon, required this.text});
  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(
            AppDimensions.paddingL, AppDimensions.paddingS, AppDimensions.paddingL, 0),
        padding: const EdgeInsets.all(AppDimensions.paddingS),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimensions.radiusS),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTextStyles.caption.copyWith(color: color))),
        ]),
      );
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.step, required this.submitting, this.onBack, this.onNext});
  final int step;
  final bool submitting;
  final VoidCallback? onBack;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: p.border))),
      child: Row(children: [
        if (step > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: onBack,
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: const Text('Back'),
            ),
          ),
        if (step > 0) const SizedBox(width: AppDimensions.paddingM),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: submitting
                ? SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: p.onAccent))
                : Text(step == 3 ? 'Submit application' : 'Continue',
                    style: AppTextStyles.button.copyWith(color: p.onAccent)),
          ),
        ),
      ]),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      backgroundColor: p.surfaceElevated,
      selectedColor: p.accent,
      side: BorderSide(color: selected ? p.accent : p.border),
      labelStyle: AppTextStyles.caption.copyWith(
        color: selected ? p.onAccent : p.textPrimary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }
}

class _UploadTile extends StatelessWidget {
  const _UploadTile({
    required this.slot,
    required this.upload,
    required this.onPick,
    this.previewUrl,
  });
  final _DocSlot slot;
  final _Upload upload;
  final VoidCallback? onPick;
  final String? previewUrl;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final done = upload.path != null && !upload.uploading;

    Widget preview;
    if (upload.bytes != null) {
      preview = Image.memory(upload.bytes!, fit: BoxFit.cover);
    } else if (previewUrl != null) {
      preview = CarNetworkImage(url: previewUrl, iconSize: 24);
    } else {
      preview = ColoredBox(
        color: p.surface,
        child: Icon(done ? Icons.check_circle_outline_rounded : slot.icon,
            color: done ? p.success : p.textTertiary),
      );
    }

    return Material(
      color: p.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        side: BorderSide(color: upload.error != null ? p.error : (done ? p.success : p.border)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: upload.uploading ? null : onPick,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingS),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
              child: SizedBox(
                width: 72, height: 56,
                child: Stack(fit: StackFit.expand, children: [
                  preview,
                  if (upload.uploading)
                    const ColoredBox(
                      color: Colors.black38,
                      child: Center(
                        child: SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
            const SizedBox(width: AppDimensions.paddingM),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(slot.label, style: AppTextStyles.bodyBold.copyWith(color: p.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  upload.error ??
                      (upload.uploading
                          ? 'Uploading…'
                          : done
                              ? 'Uploaded · tap to replace'
                              : slot.hint),
                  style: AppTextStyles.caption.copyWith(
                    color: upload.error != null
                        ? p.error
                        : (done ? p.success : p.textSecondary),
                  ),
                ),
              ]),
            ),
            Icon(done ? Icons.refresh_rounded : Icons.upload_rounded, color: p.accentSecondary),
          ]),
        ),
      ),
    );
  }
}

// lib/features/admin/verification_desk.dart
//
// Super-admin "Verification Desk": dealership applications by status, an
// inspection dialog with identity, showroom photo, documents (short-lived
// signed URLs from the private bucket) and inventory scale, and the
// approve / reject decisions (server-side RPCs).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';

import 'admin_providers.dart';

final _dateFormat = DateFormat('d MMM yyyy, h:mm a');

const _tabs = [
  ('pending', 'Pending Approvals'),
  ('approved', 'Approved'),
  ('rejected', 'Rejected'),
  ('suspended', 'Suspended'),
];

class VerificationDesk extends StatefulWidget {
  const VerificationDesk({super.key, required this.summary});
  final PlatformSummary summary;

  @override
  State<VerificationDesk> createState() => _VerificationDeskState();
}

class _VerificationDeskState extends State<VerificationDesk> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (status, _) = _tabs[_tab];
    final rows = widget.summary.withStatus(status)
      ..sort((a, b) => (b.submittedAt ?? DateTime(0)).compareTo(a.submittedAt ?? DateTime(0)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppDimensions.paddingS,
          runSpacing: AppDimensions.paddingS,
          children: [
            for (var i = 0; i < _tabs.length; i++)
              ChoiceChip(
                label: Text('${_tabs[i].$2} (${widget.summary.withStatus(_tabs[i].$1).length})'),
                selected: _tab == i,
                showCheckmark: false,
                selectedColor: p.accent,
                backgroundColor: p.card,
                side: BorderSide(color: _tab == i ? p.accent : p.border),
                labelStyle: AppTextStyles.caption.copyWith(
                  color: _tab == i ? p.onAccent : p.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) => setState(() => _tab = i),
              ),
          ],
        ),
        const SizedBox(height: AppDimensions.paddingM),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingXL),
            child: Text('Nothing here.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: p.textSecondary)),
          )
        else
          for (final row in rows) _ApplicationTile(row: row),
      ],
    );
  }
}

class _ApplicationTile extends ConsumerStatefulWidget {
  const _ApplicationTile({required this.row});
  final AdminDealerRow row;

  @override
  ConsumerState<_ApplicationTile> createState() => _ApplicationTileState();
}

class _ApplicationTileState extends ConsumerState<_ApplicationTile> {
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
    final r = widget.row;
    final d = r.dealer;
    final subtitle = [
      if (r.ownerName != null) r.ownerName!,
      if (d.city.isNotEmpty) d.city,
      if (r.submittedAt != null) 'Submitted ${_dateFormat.format(r.submittedAt!)}',
      if (!r.isApplication) 'Registered by admin',
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingS),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(color: p.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        onTap: () => showDialog(
          context: context,
          builder: (_) => ApplicationInspectionDialog(dealerId: d.id),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.name,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyBold.copyWith(color: p.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(color: p.textSecondary)),
                if (r.status == 'rejected' && r.rejectionReason != null)
                  Text('Reason: ${r.rejectionReason}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(color: p.error)),
              ]),
            ),
            if (r.status == 'approved' || r.status == 'suspended') ...[
              _Count(icon: Icons.directions_car_outlined, value: r.carCount, label: 'cars'),
              _Count(icon: Icons.forum_outlined, value: r.leadCount, label: 'leads'),
            ],
            const SizedBox(width: AppDimensions.paddingS),
            if (_busy)
              const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            else if (r.status == 'approved')
              OutlinedButton(
                onPressed: () => _setStatus('suspended'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: p.error, side: BorderSide(color: p.error)),
                child: const Text('Suspend'),
              )
            else if (r.status == 'suspended')
              ElevatedButton(
                onPressed: () => _setStatus('approved'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: p.accent, foregroundColor: p.onAccent),
                child: const Text('Reactivate'),
              )
            else
              TextButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => ApplicationInspectionDialog(dealerId: d.id),
                ),
                icon: const Icon(Icons.fact_check_outlined, size: 18),
                label: Text(r.status == 'pending' ? 'Review' : 'View'),
              ),
          ]),
        ),
      ),
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
        Text('$value $label', style: AppTextStyles.body.copyWith(color: p.textPrimary, fontSize: 13)),
      ]),
    );
  }
}

// ── Inspection dialog ──────────────────────────────────────────────────────

class ApplicationInspectionDialog extends ConsumerStatefulWidget {
  const ApplicationInspectionDialog({super.key, required this.dealerId});
  final String dealerId;

  @override
  ConsumerState<ApplicationInspectionDialog> createState() => _ApplicationInspectionDialogState();
}

class _ApplicationInspectionDialogState extends ConsumerState<ApplicationInspectionDialog> {
  bool _deciding = false;
  String? _error;

  Future<void> _approve(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve dealership?'),
        content: Text(
            '$name will become visible to buyers, and the applicant will be made the '
            'dealership owner and can sign in to the Dealer Dashboard.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Approve')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _decide(() => approveApplication(ref, widget.dealerId), '$name approved');
  }

  Future<void> _reject(String name) async {
    final reason = await showDialog<String>(context: context, builder: (_) => const _RejectDialog());
    if (reason == null || !mounted) return;
    await _decide(() => rejectApplication(ref, widget.dealerId, reason), '$name rejected');
  }

  Future<void> _decide(Future<String?> Function() action, String successMessage) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _deciding = true;
      _error = null;
    });
    final error = await action();
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
    } else {
      setState(() {
        _deciding = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final detailAsync = ref.watch(applicationDetailProvider(widget.dealerId));

    return Dialog(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppDimensions.paddingL),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 860),
        child: detailAsync.when(
          loading: () => const SizedBox(height: 240, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingXL),
            child: Text('Could not load this application: $e',
                style: AppTextStyles.body.copyWith(color: p.error)),
          ),
          data: (a) => _content(context, p, a),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, AppPalette p, ApplicationDetail a) {
    final name = a.d('name') ?? 'Dealership';
    final status = a.d('status') ?? 'pending';
    final submitted = DateTime.tryParse(a.d('submitted_at') ?? a.d('created_at') ?? '')?.toLocal();
    final inv = a.inventory;
    final makes = (inv['primary_makes'] as List?)?.map((e) => e.toString()).toList() ?? const [];
    final sample = inv['sample_vehicle'] is Map ? Map<String, dynamic>.from(inv['sample_vehicle'] as Map) : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 12, 12),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: AppTextStyles.heading2.copyWith(color: p.textPrimary, fontSize: 19)),
                if (submitted != null)
                  Text('Submitted ${_dateFormat.format(submitted)}',
                      style: AppTextStyles.caption.copyWith(color: p.textTertiary)),
              ]),
            ),
            _StatusChip(status: status),
            IconButton(
              icon: Icon(Icons.close_rounded, color: p.textMuted),
              onPressed: _deciding ? null : () => Navigator.of(context).pop(),
            ),
          ]),
        ),
        Divider(height: 1, color: p.border),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (status == 'rejected' && a.d('rejection_reason') != null)
                  _Callout(color: p.error, text: 'Rejected: ${a.d('rejection_reason')}'),
                if (a.verification == null)
                  _Callout(
                    color: p.warning,
                    text: 'No verification documents — this dealership was registered '
                        'directly by an admin, not through an application.',
                  ),

                _Section('Owner identity', [
                  _Field('Full legal name', a.v('owner_full_name')),
                  _Field('CNIC', a.v('owner_cnic')),
                  _Field('Owner phone', a.v('owner_phone')),
                ]),

                _Section('Showroom', [
                  if (a.urls['showroom'] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _DocThumb(
                          label: 'Showroom exterior', url: a.urls['showroom']!, height: 220),
                    ),
                  _Field('Address', a.d('address')),
                  _Field('City', a.d('city')),
                  _Field('Business WhatsApp', a.d('contact_phone')),
                  _Field('Operating hours', a.d('business_hours')),
                  _Field('NTN / registration no.', a.v('ntn_number')),
                ]),

                if (a.verification != null)
                  _Section('Documents', [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final (key, label) in const [
                          ('cnic_front', 'CNIC — front'),
                          ('cnic_back', 'CNIC — back'),
                          ('business_doc', 'Business proof'),
                        ])
                          SizedBox(
                            width: 200,
                            child: a.urls[key] == null
                                ? _Field(label, 'Could not load (check storage policies)')
                                : _DocThumb(label: label, url: a.urls[key]!, height: 130),
                          ),
                      ],
                    ),
                  ]),

                if (inv.isNotEmpty)
                  _Section('Inventory & scale', [
                    _Field('Expected stock', inv['expected_stock_size'] == null
                        ? null
                        : '${inv['expected_stock_size']} cars'),
                    if (makes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(spacing: 6, runSpacing: 6, children: [
                          for (final m in makes)
                            Chip(
                              label: Text(m),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: p.surface,
                              side: BorderSide(color: p.border),
                              labelStyle: AppTextStyles.caption.copyWith(color: p.textPrimary),
                            ),
                        ]),
                      ),
                    if (sample != null)
                      _Field('Sample vehicle',
                          '${sample['year'] ?? ''} ${sample['make'] ?? ''} ${sample['model'] ?? ''}'
                          '${sample['price'] != null ? ' · PKR ${sample['price']}' : ''}'),
                  ]),
              ],
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(_error!, style: AppTextStyles.caption.copyWith(color: p.error)),
          ),
        if (status == 'pending') ...[
          Divider(height: 1, color: p.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              OutlinedButton.icon(
                onPressed: _deciding ? null : () => _reject(name),
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Reject Application'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: p.error, side: BorderSide(color: p.error)),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _deciding ? null : () => _approve(name),
                icon: _deciding
                    ? SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: p.onAccent))
                    : const Icon(Icons.verified_rounded, size: 18),
                label: const Text('Approve Dealership'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: p.success, foregroundColor: Colors.white),
              ),
            ]),
          ),
        ],
      ],
    );
  }
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog();
  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _ctrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  static const _quickReasons = [
    'Showroom facade photo is unclear',
    'CNIC images are unreadable or invalid',
    'Business proof does not match the showroom',
    'Name on CNIC does not match the applicant',
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AlertDialog(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      title: const Text('Reject application'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('The applicant sees this reason and can fix and resubmit.',
                style: AppTextStyles.caption.copyWith(color: p.textSecondary)),
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final r in _quickReasons)
                ActionChip(
                  label: Text(r),
                  labelStyle: AppTextStyles.caption.copyWith(color: p.textPrimary),
                  backgroundColor: p.surface,
                  side: BorderSide(color: p.border),
                  onPressed: () => _ctrl.text = r,
                ),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ctrl,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Rejection reason'),
              validator: (v) =>
                  (v == null || v.trim().length < 5) ? 'Give the applicant a clear reason' : null,
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(_ctrl.text.trim());
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: p.error, foregroundColor: Colors.white),
          child: const Text('Reject'),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = switch (status) {
      'approved' => p.success,
      'pending' => p.warning,
      _ => p.error,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status,
          style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(text, style: AppTextStyles.body.copyWith(color: color, fontSize: 13)),
      );
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title.toUpperCase(),
            style: AppTextStyles.caption.copyWith(
                color: p.textMuted, fontWeight: FontWeight.w700, letterSpacing: 0.5, fontSize: 11)),
        const SizedBox(height: 8),
        ...children,
      ]),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final has = value != null && value!.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 170,
          child: Text(label, style: AppTextStyles.caption.copyWith(color: p.textSecondary)),
        ),
        Expanded(
          child: SelectableText(has ? value! : '—',
              style: AppTextStyles.body.copyWith(
                  color: has ? p.textPrimary : p.textMuted, fontSize: 13.5)),
        ),
      ]),
    );
  }
}

/// Tappable thumbnail; opens a full-size, zoomable preview.
class _DocThumb extends StatelessWidget {
  const _DocThumb({required this.label, required this.url, required this.height});
  final String label;
  final String url;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTextStyles.caption.copyWith(color: p.textSecondary)),
      const SizedBox(height: 4),
      Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showDialog(
            context: context,
            builder: (ctx) => Dialog(
              backgroundColor: Colors.black,
              insetPadding: const EdgeInsets.all(24),
              child: Stack(children: [
                InteractiveViewer(
                  maxScale: 5,
                  child: Center(child: CarNetworkImage(url: url, fit: BoxFit.contain, iconSize: 48)),
                ),
                Positioned(
                  top: 8, right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ]),
            ),
          ),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: CarNetworkImage(url: url, iconSize: 28),
          ),
        ),
      ),
    ]);
  }
}

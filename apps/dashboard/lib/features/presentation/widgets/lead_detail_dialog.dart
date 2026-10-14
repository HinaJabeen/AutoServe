// lib/features/presentation/widgets/lead_detail_dialog.dart
//
// Opened from a Kanban card. Stage changes save immediately and refresh the
// board; internal notes live in `lead_activity` (see lead_activity_provider).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/lead_activity_provider.dart';
import '../../providers/lead_provider.dart';
import '../../providers/overview_provider.dart' hide dealerLeadsStreamProvider;

/// `leads.stage` values in pipeline order → labels.
const leadStageLabels = {
  'new': 'New Inquiry',
  'contacted': 'Contacted',
  'test_drive_scheduled': 'Test Drive Scheduled',
  'negotiating': 'Negotiation',
  'closed_won': 'Closed — Won',
  'closed_lost': 'Closed — Lost',
};

const _sourceLabels = {
  'test_drive_request': 'Test drive request',
  'inquiry': 'Inquiry',
  'swipe_interest': 'Swipe interest',
  'walk_in': 'Walk-in',
  'online': 'Online',
};

final _timestampFormat = DateFormat('d MMM yyyy, h:mm a');

/// The customer app folds the contact email into `leads.notes`
/// ("Contact email: x") because `leads` has no email column.
String? emailFromNotes(String? notes) {
  if (notes == null) return null;
  return RegExp(r'Contact email:\s*(\S+@\S+)').firstMatch(notes)?.group(1);
}

class LeadDetailDialog extends ConsumerStatefulWidget {
  const LeadDetailDialog({super.key, required this.lead, required this.vehicleTitle});
  final LeadModel lead;
  final String vehicleTitle;

  @override
  ConsumerState<LeadDetailDialog> createState() => _LeadDetailDialogState();
}

class _LeadDetailDialogState extends ConsumerState<LeadDetailDialog> {
  late String _stage = widget.lead.status;
  final _noteCtrl = TextEditingController();
  bool _savingNote = false;
  String? _error;

  LeadModel get lead => widget.lead;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _changeStage(String? stage) async {
    if (stage == null || stage == _stage) return;
    final previous = _stage;
    setState(() {
      _stage = stage;
      _error = null;
    });
    final ok = await ref.read(leadNotifierProvider.notifier).updateStatus(lead.id, stage);
    if (!mounted) return;
    if (ok) {
      // Refetch so the card moves columns even if realtime isn't enabled yet.
      ref.invalidate(dealerLeadsStreamProvider);
    } else {
      setState(() {
        _stage = previous;
        _error = 'Could not update stage. ${ref.read(leadNotifierProvider).errorMessage ?? ''}';
      });
    }
  }

  Future<void> _addNote() async {
    setState(() {
      _savingNote = true;
      _error = null;
    });
    final error = await addLeadNote(ref, lead.id, _noteCtrl.text);
    if (!mounted) return;
    setState(() {
      _savingNote = false;
      _error = error;
      if (error == null) _noteCtrl.clear();
    });
  }

  Future<void> _open(Uri? uri) async {
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) setState(() => _error = 'Could not open $uri');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final email = lead.consumerEmail ?? emailFromNotes(lead.notes);
    final dealerName = ref.watch(currentDealershipProvider).valueOrNull?.name;
    final whatsAppMessage = 'Hi ${lead.consumerName}, this is '
        '${dealerName ?? 'the dealership'} about your inquiry for ${widget.vehicleTitle}.';
    final callUri = ContactLinks.call(lead.consumerPhone);
    final whatsAppUri = ContactLinks.whatsApp(lead.consumerPhone, message: whatsAppMessage);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 760),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.border),
          boxShadow: [
            BoxShadow(color: p.shadowColor.withValues(alpha: 0.25),
                blurRadius: 40, offset: const Offset(0, 16)),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(lead.consumerName,
                      style: AppTextStyles.heading2.copyWith(color: p.textPrimary, fontSize: 18)),
                ),
                _SourceBadge(source: lead.type),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: p.textMuted, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ]),
              const SizedBox(height: 4),
              _row(p, Icons.directions_car_outlined, widget.vehicleTitle),
              _row(p, Icons.phone_outlined, lead.consumerPhone ?? 'No phone provided'),
              if (email != null) _row(p, Icons.mail_outline_rounded, email),
              _row(p, Icons.schedule_rounded,
                  'Received ${_timestampFormat.format(lead.createdAt.toLocal())}'),
              const SizedBox(height: 14),

              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: callUri == null ? null : () => _open(callUri),
                    icon: Icon(Icons.call_rounded, size: 16, color: p.accent),
                    label: Text('Call Customer', style: TextStyle(color: p.accent)),
                    style: OutlinedButton.styleFrom(side: BorderSide(color: p.accent)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: whatsAppUri == null ? null : () => _open(whatsAppUri),
                    icon: const Icon(Icons.chat_rounded, size: 16),
                    label: const Text('Open WhatsApp'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: p.success,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 18),

              _label(p, 'Stage'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: leadStageLabels.containsKey(_stage) ? _stage : null,
                isExpanded: true,
                dropdownColor: p.card,
                style: AppTextStyles.body.copyWith(color: p.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: p.surface,
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: p.border)),
                ),
                items: [
                  for (final e in leadStageLabels.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: ref.watch(leadNotifierProvider).isLoading ? null : _changeStage,
              ),

              if (lead.notes != null && lead.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: 18),
                _label(p, 'Customer message'),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(lead.notes!,
                      style: AppTextStyles.body.copyWith(color: p.textSecondary, fontSize: 12.5)),
                ),
              ],

              const SizedBox(height: 18),
              _label(p, 'Internal notes'),
              const SizedBox(height: 6),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: TextField(
                    controller: _noteCtrl,
                    minLines: 1,
                    maxLines: 4,
                    style: AppTextStyles.body.copyWith(color: p.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'e.g. Called — wants a weekend test drive',
                      hintStyle: AppTextStyles.body.copyWith(color: p.textMuted, fontSize: 13),
                      filled: true,
                      fillColor: p.surface,
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: p.border)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _savingNote ? null : _addNote,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: p.accent, foregroundColor: p.onAccent),
                  child: _savingNote
                      ? SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: p.onAccent))
                      : const Text('Add'),
                ),
              ]),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: AppTextStyles.caption.copyWith(color: p.error)),
              ],
              const SizedBox(height: 10),
              _NotesList(leadId: lead.id),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(AppPalette p, String text) => Text(text.toUpperCase(),
      style: AppTextStyles.caption.copyWith(
          color: p.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4));

  Widget _row(AppPalette p, IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 7),
        child: Row(children: [
          Icon(icon, size: 14, color: p.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(text,
                style: AppTextStyles.body.copyWith(color: p.textSecondary, fontSize: 12.5)),
          ),
        ]),
      );
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.source});
  final String source;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final label = _sourceLabels[source] ??
        source.split('_').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
    final isTestDrive = source == 'test_drive_request';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: p.badgeBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isTestDrive ? Icons.event_available_outlined : Icons.chat_bubble_outline_rounded,
            size: 12, color: p.badgeText),
        const SizedBox(width: 4),
        Text(label,
            style: AppTextStyles.caption.copyWith(
                color: p.badgeText, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _NotesList extends ConsumerWidget {
  const _NotesList({required this.leadId});
  final String leadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    return ref.watch(leadNotesProvider(leadId)).when(
          loading: () => const Padding(
            padding: EdgeInsets.all(8),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, _) => Text('Could not load notes: $e',
              style: AppTextStyles.caption.copyWith(color: p.error)),
          data: (notes) => notes.isEmpty
              ? Text('No notes yet.',
                  style: AppTextStyles.caption.copyWith(color: p.textMuted))
              : Column(
                  children: [
                    for (final n in notes)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border(left: BorderSide(color: p.accent, width: 2)),
                          color: p.surface,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_timestampFormat.format(n.createdAt),
                                style: AppTextStyles.caption
                                    .copyWith(color: p.textMuted, fontSize: 10.5)),
                            const SizedBox(height: 2),
                            SelectableText(n.note,
                                style: AppTextStyles.body
                                    .copyWith(color: p.textPrimary, fontSize: 12.5)),
                          ],
                        ),
                      ),
                  ],
                ),
        );
  }
}

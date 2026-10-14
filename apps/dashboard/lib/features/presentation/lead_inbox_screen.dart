// lib/features/presentation/lead_inbox_screen.dart
// PART 3: Full Kanban CRM Lead Pipeline.
// 4 columns: New Inquiries | Contact Established | Dynamic Test | Finance & Closing
// LongPressDraggable cards, DragTarget columns, unique ValueKeys, no GlobalKey in build().

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../providers/overview_provider.dart' hide dealerLeadsStreamProvider;
import '../providers/lead_provider.dart';
import '../../theme/app_palette.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt.toLocal());
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24)   return '${diff.inHours}h ago';
  if (diff.inDays < 7)     return '${diff.inDays}d ago';
  final l = dt.toLocal();
  return '${l.day}/${l.month}/${l.year}';
}

// DB stage values → display labels + column buckets
class _Stage {
  const _Stage(this.key, this.label, this.icon);
  final String key;
  final String label;
  final IconData icon;
}

const _stages = [
  _Stage('new',                  'New Inquiries',        Icons.fiber_new_rounded),
  _Stage('contacted',            'Contact Established',  Icons.handshake_outlined),
  _Stage('test_drive_scheduled', 'Dynamic Test',         Icons.directions_car_rounded),
  _Stage('negotiating',          'Finance & Closing',    Icons.request_quote_outlined),
];

// Closed stages rendered as chips below the board, not draggable columns.
const _closedStages = {
  'closed_won':  'Won',
  'closed_lost': 'Lost',
};

const _allStatusLabels = {
  'new':                  'New',
  'contacted':            'Contacted',
  'test_drive_scheduled': 'Test Drive',
  'negotiating':          'Negotiating',
  'closed_won':           'Closed Won',
  'closed_lost':          'Closed Lost',
};

// ─── Screen ───────────────────────────────────────────────────────────────────

class LeadInboxScreen extends ConsumerStatefulWidget {
  const LeadInboxScreen({super.key});
  @override
  ConsumerState<LeadInboxScreen> createState() => _LeadInboxScreenState();
}

class _LeadInboxScreenState extends ConsumerState<LeadInboxScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  // Track which column is currently being hovered during drag
  String? _hoveredStage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(unreadLeadCountProvider.notifier).clear();
    });
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leadsAsync    = ref.watch(dealerLeadsStreamProvider);
    final vehiclesAsync = ref.watch(dealerVehiclesStreamProvider);
    final p             = context.palette;
    final isDark        = Theme.of(context).brightness == Brightness.dark;

    // Surface a failed drag-and-drop stage update — the card silently stays
    // in its old column otherwise (the leads stream is the source of truth,
    // so a failed write just never moves it), with no indication why.
    ref.listen<LeadMutationState>(leadNotifierProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update lead: ${next.errorMessage}')),
        );
      }
    });

    final vehiclesById = <String, CarModel>{};
    for (final raw in vehiclesAsync.value ?? []) {
      final v = CarModel.fromJson(Map<String, dynamic>.from(raw));
      vehiclesById[v.id] = v;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header bar ────────────────────────────────────────────────────────
        _HeaderBar(p: p, isDark: isDark, searchCtrl: _searchCtrl),

        // ── Content ───────────────────────────────────────────────────────────
        Expanded(
          child: leadsAsync.when(
            loading: () => Center(
              child: CircularProgressIndicator(color: p.accent, strokeWidth: 2),
            ),
            error: (e, _) => _ErrorState(
              message: e.toString(), p: p,
              onRetry: () => ref.invalidate(dealerLeadsStreamProvider),
            ),
            data: (allLeads) {
              final leads = _query.isEmpty
                  ? allLeads
                  : allLeads.where((l) =>
                      l.consumerName.toLowerCase().contains(_query) ||
                      (vehiclesById[l.vehicleId]?.displayTitle ?? '')
                          .toLowerCase().contains(_query)).toList();

              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _stages.map((stage) {
                    final stageLeads = leads
                        .where((l) => l.status == stage.key)
                        .toList();
                    final isHovered = _hoveredStage == stage.key;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _KanbanColumn(
                          key: ValueKey('col_${stage.key}'),
                          stage: stage,
                          leads: stageLeads,
                          vehiclesById: vehiclesById,
                          p: p,
                          isDark: isDark,
                          isHovered: isHovered,
                          allStatusLabels: _allStatusLabels,
                          onWillAccept: (stageKey) {
                            setState(() => _hoveredStage = stageKey);
                            return true;
                          },
                          onLeave: (_) {
                            setState(() => _hoveredStage = null);
                          },
                          onAccept: (lead, newStage) async {
                            setState(() => _hoveredStage = null);
                            if (lead.status == newStage) return;
                            await ref
                                .read(leadNotifierProvider.notifier)
                                .updateStatus(lead.id, newStage);
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Header bar ───────────────────────────────────────────────────────────────

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.p, required this.isDark, required this.searchCtrl});
  final AppPalette p;
  final bool isDark;
  final TextEditingController searchCtrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Row(children: [
        // Breadcrumbs
        _Crumb(label: 'AUTOSERVE', accent: p.accent),
        _CrumbSep(p: p),
        _Crumb(label: 'DRIVE', p: p),
        _CrumbSep(p: p),
        _Crumb(label: 'TELEMETRY', p: p),
        _CrumbSep(p: p),
        _Crumb(label: 'LEADS', accent: p.accent),
        const Spacer(),
        // Search
        SizedBox(
          width: 220,
          height: 36,
          child: TextField(
            controller: searchCtrl,
            style: AppTextStyles.body.copyWith(color: p.textPrimary, fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Search leads…',
              hintStyle: AppTextStyles.caption.copyWith(color: p.textMuted),
              prefixIcon: Icon(Icons.search_rounded, size: 16, color: p.textMuted),
              contentPadding: EdgeInsets.zero,
              isDense: true,
              filled: true,
              fillColor: p.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: p.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: p.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: p.accent, width: 1.5),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Crumb extends StatelessWidget {
  const _Crumb({required this.label, this.accent, this.p});
  final String label;
  final Color? accent;
  final AppPalette? p;
  @override
  Widget build(BuildContext context) {
    final pal = p ?? context.palette;
    return Text(label,
        style: AppTextStyles.caption.copyWith(
          color: accent ?? pal.textMuted,
          fontSize: 10,
          fontWeight: accent != null ? FontWeight.w700 : FontWeight.w400,
          letterSpacing: 1.2,
        ));
  }
}

class _CrumbSep extends StatelessWidget {
  const _CrumbSep({required this.p});
  final AppPalette p;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Text('›', style: TextStyle(color: p.textMuted, fontSize: 11)),
  );
}

// ─── Kanban column ────────────────────────────────────────────────────────────

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({
    super.key,
    required this.stage,
    required this.leads,
    required this.vehiclesById,
    required this.p,
    required this.isDark,
    required this.isHovered,
    required this.allStatusLabels,
    required this.onWillAccept,
    required this.onLeave,
    required this.onAccept,
  });

  final _Stage stage;
  final List<LeadModel> leads;
  final Map<String, dynamic> vehiclesById;
  final AppPalette p;
  final bool isDark, isHovered;
  final Map<String, String> allStatusLabels;
  final bool Function(String) onWillAccept;
  final void Function(LeadModel?) onLeave;
  final void Function(LeadModel, String) onAccept;

  @override
  Widget build(BuildContext context) {
    return DragTarget<LeadModel>(
      key: ValueKey('target_${stage.key}'),
      onWillAcceptWithDetails: (d) => onWillAccept(stage.key),
      onLeave: onLeave,
      onAcceptWithDetails: (d) => onAccept(d.data, stage.key),
      builder: (context, candidateData, rejectedData) {
        final accepting = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: accepting
                ? p.accent.withValues(alpha: 0.06)
                : p.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: accepting ? p.accent : p.border,
              width: accepting ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Column header
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(children: [
                  Icon(stage.icon, size: 14, color: p.accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(stage.label,
                        style: AppTextStyles.caption.copyWith(
                          color: p.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        )),
                  ),
                  // Count badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: p.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: p.accent.withValues(alpha: 0.3)),
                    ),
                    child: Text('${leads.length}',
                        style: AppTextStyles.caption.copyWith(
                          color: p.accent, fontSize: 10,
                          fontWeight: FontWeight.w700,
                        )),
                  ),
                ]),
              ),
              Divider(color: p.border, height: 1),
              // Cards
              Expanded(
                child: leads.isEmpty
                    ? _EmptyColumn(p: p)
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: leads.length,
                        itemBuilder: (context, i) {
                          final lead = leads[i];
                          final vehicle = lead.vehicleId != null
                              ? vehiclesById[lead.vehicleId]
                              : null;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _LeadCard(
                              key: ValueKey('lead_${lead.id}'),
                              lead: lead,
                              vehicle: vehicle,
                              p: p,
                              isDark: isDark,
                              allStatusLabels: allStatusLabels,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyColumn extends StatelessWidget {
  const _EmptyColumn({required this.p});
  final AppPalette p;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inbox_outlined, size: 28, color: p.textMuted),
        const SizedBox(height: 6),
        Text('No leads', style: AppTextStyles.caption.copyWith(
            color: p.textMuted, fontSize: 11)),
      ]),
    ),
  );
}

// ─── Lead card — draggable ────────────────────────────────────────────────────

class _LeadCard extends StatelessWidget {
  const _LeadCard({
    super.key,
    required this.lead,
    required this.vehicle,
    required this.p,
    required this.isDark,
    required this.allStatusLabels,
  });

  final LeadModel lead;
  final dynamic vehicle;
  final AppPalette p;
  final bool isDark;
  final Map<String, String> allStatusLabels;

  @override
  Widget build(BuildContext context) {
    final initials = lead.consumerName.isNotEmpty
        ? lead.consumerName.trim().split(' ')
            .take(2).map((w) => w[0].toUpperCase()).join()
        : '?';
    final vehicleTitle = vehicle?.displayTitle as String? ?? 'General inquiry';
    final price = vehicle?.price as double?;

    final card = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
        boxShadow: [
          BoxShadow(
            color: p.shadowColor.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 8, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: initials badge + name + time
          Row(children: [
            // Initials badge
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: p.badgeBackground,
                shape: BoxShape.circle,
                border: Border.all(color: p.accent.withValues(alpha: 0.3)),
              ),
              child: Center(
                child: Text(initials,
                    style: TextStyle(
                      color: p.badgeText,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(lead.consumerName,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyBold.copyWith(
                      color: p.textPrimary, fontSize: 12.5)),
            ),
            Text(_timeAgo(lead.createdAt),
                style: AppTextStyles.caption.copyWith(
                    color: p.textMuted, fontSize: 10)),
          ]),
          const SizedBox(height: 8),

          // Vehicle pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: p.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: p.accent.withValues(alpha: 0.2)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.directions_car_outlined, size: 11, color: p.accent),
              const SizedBox(width: 4),
              Flexible(
                child: Text(vehicleTitle,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                        color: p.accent, fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
          ),

          // Price + phone row
          if (price != null || lead.consumerPhone != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              if (price != null) ...[
                Icon(Icons.attach_money, size: 11, color: p.success),
                Text(
                  'PKR ${price.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d)(?=(\d{3})+(?!\d))"), (m) => "${m[1]},")}',
                  style: AppTextStyles.caption.copyWith(
                      color: p.success, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ],
              const Spacer(),
              if (lead.consumerPhone != null)
                Row(children: [
                  Icon(Icons.phone_outlined, size: 11, color: p.textMuted),
                  const SizedBox(width: 3),
                  Text(lead.consumerPhone!,
                      style: AppTextStyles.caption.copyWith(
                          color: p.textMuted, fontSize: 10)),
                ]),
            ]),
          ],
        ],
      ),
    );

    // Plain Draggable (not LongPressDraggable): this board is mouse-driven on
    // a web dashboard, so drags should start on press-and-move immediately
    // rather than waiting out a touch-oriented long-press delay.
    return Draggable<LeadModel>(
      key: ValueKey('drag_${lead.id}'),
      data: lead,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 220,
          child: Opacity(opacity: 0.88, child: card),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: GestureDetector(
        onTap: () => showDialog(
          context: context,
          builder: (_) => _LeadDetailDialog(lead: lead, vehicleTitle: vehicleTitle, p: p),
        ),
        child: card,
      ),
    );
  }
}

// ─── Lead detail dialog ───────────────────────────────────────────────────────

class _LeadDetailDialog extends ConsumerWidget {
  const _LeadDetailDialog({
    required this.lead, required this.vehicleTitle, required this.p});
  final LeadModel lead;
  final String vehicleTitle;
  final AppPalette p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mutation   = ref.watch(leadNotifierProvider);
    final isUpdating = mutation.isLoading;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.border),
          boxShadow: [
            BoxShadow(color: p.shadowColor.withValues(alpha: 0.35),
                blurRadius: 40, offset: const Offset(0, 16)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(lead.consumerName,
                    style: AppTextStyles.heading2.copyWith(
                        color: p.textPrimary, fontSize: 18)),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: p.textMuted, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ]),
            const SizedBox(height: 8),
            _dRow(p, Icons.directions_car_outlined, vehicleTitle),
            if (lead.consumerPhone != null)
              _dRow(p, Icons.phone_outlined, lead.consumerPhone!),
            if (lead.consumerEmail != null)
              _dRow(p, Icons.mail_outline_rounded, lead.consumerEmail!),
            _dRow(p,
              lead.type == 'test_drive'
                  ? Icons.event_available_outlined
                  : Icons.chat_bubble_outline_rounded,
              lead.type == 'test_drive' ? 'Test drive request' : 'Inquiry'),
            _dRow(p, Icons.schedule_rounded, _timeAgo(lead.createdAt)),
            if (lead.notes != null && lead.notes!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(lead.notes!,
                    style: AppTextStyles.body.copyWith(
                        color: p.textSecondary, fontSize: 12.5)),
              ),
            ],
            const SizedBox(height: 16),
            Text('Update status',
                style: AppTextStyles.caption.copyWith(
                    color: p.textMuted, fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 0.4)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _allStatusLabels.entries.map((e) {
                final isCurrent = lead.status == e.key;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: isCurrent || isUpdating ? null : () async {
                      final ok = await ref
                          .read(leadNotifierProvider.notifier)
                          .updateStatus(lead.id, e.key);
                      if (ok && context.mounted) Navigator.of(context).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? p.accent.withValues(alpha: 0.16)
                            : p.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: isCurrent
                                ? p.accent.withValues(alpha: 0.5)
                                : p.border),
                      ),
                      child: Text(e.value,
                          style: AppTextStyles.caption.copyWith(
                            color: isCurrent ? p.accent : p.textSecondary,
                            fontSize: 12,
                            fontWeight: isCurrent
                                ? FontWeight.w700 : FontWeight.w400,
                          )),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dRow(AppPalette p, IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 7),
    child: Row(children: [
      Icon(icon, size: 14, color: p.textMuted),
      const SizedBox(width: 8),
      Expanded(child: Text(text,
          style: AppTextStyles.body.copyWith(
              color: p.textSecondary, fontSize: 12.5))),
    ]),
  );
}

// ─── Empty / error states ─────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.p, required this.onRetry});
  final String message;
  final AppPalette p;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.error_outline_rounded, color: p.error, size: 28),
      const SizedBox(height: 8),
      Text('Could not load leads',
          style: AppTextStyles.bodyBold.copyWith(color: p.textPrimary)),
      const SizedBox(height: 4),
      Text(message,
          style: AppTextStyles.caption.copyWith(color: p.textSecondary),
          textAlign: TextAlign.center),
      const SizedBox(height: 12),
      TextButton.icon(
        onPressed: onRetry,
        icon: Icon(Icons.refresh_rounded, size: 16, color: p.accent),
        label: Text('Retry',
            style: AppTextStyles.body.copyWith(color: p.accent)),
      ),
    ]),
  );
}
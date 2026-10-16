// lib/features/reports/export_report_menu.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../core/download/file_download.dart';
import '../providers/lead_provider.dart' as kanban;
import '../providers/overview_provider.dart';
import 'report_export_service.dart';

enum _ExportAction { leadsCsv, monthlyPdf }

class ExportReportMenu extends ConsumerStatefulWidget {
  const ExportReportMenu({super.key});

  @override
  ConsumerState<ExportReportMenu> createState() => _ExportReportMenuState();
}

class _ExportReportMenuState extends ConsumerState<ExportReportMenu> {
  bool _busy = false;
  static const _service = ReportExportService();

  String _datePart() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Map<String, String> _vehicleTitles() {
    final cars = ref.read(dealerCarsStreamProvider).valueOrNull ?? const [];
    return {
      for (final c in cars)
        c['id'].toString(): '${c['year'] ?? ''} ${c['make'] ?? ''} ${c['model'] ?? ''}'.trim(),
    };
  }

  Future<void> _run(_ExportAction action) async {
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = context.palette.error;
    setState(() => _busy = true);
    try {
      // The Kanban's stream carries each lead's source (intake channel).
      final leads = await ref.read(kanban.dealerLeadsStreamProvider.future);
      final dealerName = ref.read(currentDealershipProvider).valueOrNull?.name ?? 'Dealership';
      final slug = dealerName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

      final bool saved;
      switch (action) {
        case _ExportAction.leadsCsv:
          saved = await saveBytes(
            _service.leadsCsvBytes(leads, _vehicleTitles()),
            '$slug-leads-${_datePart()}.csv',
            'text/csv;charset=utf-8',
          );
        case _ExportAction.monthlyPdf:
          final metrics = ref.read(dashboardMetricsProvider).valueOrNull;
          if (metrics == null) throw 'Metrics are still loading — try again in a moment.';
          saved = await saveBytes(
            await _service.monthlySummaryPdf(
              dealerName: dealerName,
              metrics: metrics,
              totalLeads: leads.length,
            ),
            '$slug-monthly-summary-${_datePart()}.pdf',
            'application/pdf',
          );
      }
      if (saved) {
        messenger.showSnackBar(const SnackBar(content: Text('Report downloaded')));
      }
    } catch (e) {
      debugPrint('Export failed: $e');
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: errorColor));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PopupMenuButton<_ExportAction>(
      enabled: !_busy,
      tooltip: 'Export report',
      color: p.card,
      onSelected: _run,
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _ExportAction.leadsCsv,
          child: ListTile(
            leading: Icon(Icons.table_view_outlined, color: p.accent),
            title: Text('Export Leads to CSV', style: TextStyle(color: p.textPrimary)),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: _ExportAction.monthlyPdf,
          child: ListTile(
            leading: Icon(Icons.picture_as_pdf_outlined, color: p.accent),
            title: Text('Download Monthly Summary (PDF)', style: TextStyle(color: p.textPrimary)),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: p.accent,
          borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (_busy)
            SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: p.onAccent))
          else
            Icon(Icons.file_download_outlined, size: 18, color: p.onAccent),
          const SizedBox(width: 8),
          Text('Export Report', style: AppTextStyles.button.copyWith(color: p.onAccent, fontSize: 13)),
          Icon(Icons.arrow_drop_down_rounded, color: p.onAccent),
        ]),
      ),
    );
  }
}

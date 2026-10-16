// lib/features/reports/report_export_service.dart
//
// Overview "Export Report": leads as CSV, and a one-page monthly summary PDF.

import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared/shared.dart';

import '../../core/pdf/pdf_text.dart';
import '../presentation/widgets/lead_detail_dialog.dart' show leadStageLabels;
import '../providers/overview_provider.dart' show DashboardMetrics, leadPipelineStages;

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _two(int n) => n.toString().padLeft(2, '0');
String _stamp(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';
String _pkr(num v) =>
    'PKR ${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

/// Spreadsheet apps execute cells starting with = + - @ (or tab/CR) as
/// formulas. Lead names and notes are typed by the public, so neutralise
/// them (OWASP "CSV injection").
String csvSafe(String? value) {
  final v = value ?? '';
  if (v.isNotEmpty && '=+-@\t\r'.contains(v[0])) return "'$v";
  return v;
}

class ReportExportService {
  const ReportExportService();

  static const leadCsvHeader = [
    'Lead Name', 'Phone', 'Vehicle', 'Stage', 'Source', 'Created Date', 'Notes',
  ];

  /// [vehicleTitles] maps car id → "2021 Honda Civic".
  String leadsCsv(List<LeadModel> leads, Map<String, String> vehicleTitles) {
    final rows = <List<String>>[
      leadCsvHeader,
      for (final l in leads)
        [
          csvSafe(l.consumerName),
          csvSafe(l.consumerPhone),
          csvSafe(l.vehicleId == null ? 'General inquiry' : (vehicleTitles[l.vehicleId] ?? 'Removed vehicle')),
          leadStageLabels[l.status] ?? l.status,
          csvSafe(l.type),
          _stamp(l.createdAt.toLocal()),
          csvSafe(l.notes?.replaceAll(RegExp(r'\s*\n\s*'), ' | ')),
        ],
    ];
    return const ListToCsvConverter().convert(rows);
  }

  /// UTF-8 with a BOM so Excel shows non-Latin names correctly.
  Uint8List leadsCsvBytes(List<LeadModel> leads, Map<String, String> vehicleTitles) =>
      Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(leadsCsv(leads, vehicleTitles))]);

  Future<Uint8List> monthlySummaryPdf({
    required String dealerName,
    required DashboardMetrics metrics,
    required int totalLeads,
    DateTime? now,
  }) async {
    final date = now ?? DateTime.now();
    const brand = PdfColor.fromInt(0xFF0B1F3A);
    const accent = PdfColor.fromInt(0xFF0066FF);
    final doc = pw.Document(title: 'Monthly Summary', author: 'AutoServe');

    pw.Widget kpi(String label, String value) => pw.Expanded(
          child: pw.Container(
            margin: const pw.EdgeInsets.all(4),
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(pdfSafeText(label), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              pw.SizedBox(height: 4),
              pw.Text(pdfSafeText(value),
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: brand)),
            ]),
          ),
        );

    final stageRows = [
      for (final stage in leadPipelineStages)
        (leadStageLabels[stage] ?? stage, metrics.leadsByStage[stage] ?? 0),
    ];
    final maxStage = stageRows.fold(0, (m, r) => r.$2 > m ? r.$2 : m);

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: const pw.BoxDecoration(color: brand),
            child: pw.Row(children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(pdfSafeText(dealerName, fallback: 'Dealership'),
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                pw.Text('Monthly Summary - ${_months[date.month - 1]} ${date.year}',
                    style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey300)),
              ]),
              pw.Spacer(),
              pw.Text('AutoServe',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            ]),
          ),
          pw.SizedBox(height: 18),
          pw.Text('INVENTORY', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: accent)),
          pw.SizedBox(height: 4),
          pw.Row(children: [
            kpi('Total stock', '${metrics.totalVehicles}'),
            kpi('Available', '${metrics.availableVehicles}'),
            kpi('Reserved', '${metrics.reservedVehicles}'),
          ]),
          pw.Row(children: [
            kpi('Active inventory value', _pkr(metrics.grossStockValue)),
            kpi('Cars sold this month', '${metrics.soldThisMonth}'),
            kpi('Cars sold (all time)', '${metrics.soldVehicles}'),
          ]),
          pw.SizedBox(height: 18),
          pw.Text('LEADS', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: accent)),
          pw.SizedBox(height: 4),
          pw.Row(children: [
            kpi('Leads this month', '${metrics.leadsThisMonth}'),
            kpi('Active leads', '${metrics.activeLeadsCount}'),
            kpi('All leads', '$totalLeads'),
          ]),
          pw.SizedBox(height: 12),
          pw.Text('Pipeline by stage', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          for (final (label, count) in stageRows)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Row(children: [
                pw.SizedBox(width: 140, child: pw.Text(pdfSafeText(label), style: const pw.TextStyle(fontSize: 10))),
                pw.Expanded(
                  child: pw.Stack(children: [
                    pw.Container(height: 10, color: PdfColors.grey200),
                    if (count > 0)
                      pw.Container(
                        height: 10,
                        width: 300 * (count / (maxStage == 0 ? 1 : maxStage)),
                        color: stageRows.indexOf((label, count)) >= 4 ? PdfColors.grey600 : accent,
                      ),
                  ]),
                ),
                pw.SizedBox(
                  width: 40,
                  child: pw.Text('$count',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ),
              ]),
            ),
          pw.Spacer(),
          pw.Divider(color: PdfColors.grey300),
          pw.Text('Generated ${_stamp(date)} from live AutoServe data.',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ],
      ),
    ));
    return doc.save();
  }
}

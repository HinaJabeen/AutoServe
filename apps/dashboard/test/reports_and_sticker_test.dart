import 'package:dashboard/core/pdf/pdf_text.dart';
import 'package:dashboard/features/inventory/services/window_sticker_pdf_service.dart';
import 'package:dashboard/features/presentation/lead_inbox_screen.dart' show isStaleLead;
import 'package:dashboard/features/providers/overview_provider.dart';
import 'package:dashboard/features/reports/report_export_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

CarModel _car({String? color, double? score}) => CarModel(
      id: 'abcdef12-3456', dealerId: 'd1', make: 'Honda', model: 'Civic', year: 2021,
      price: 4850000, status: 'available', createdAt: DateTime(2026), updatedAt: DateTime(2026),
      color: color, inspectionScore: score,
    );

LeadModel _lead({String status = 'new', required DateTime createdAt, String name = 'Ali'}) => LeadModel(
      id: 'l1', dealershipId: 'd1', vehicleId: 'c1', consumerName: name,
      consumerPhone: '+923001234567', type: 'inquiry', status: status, createdAt: createdAt,
      notes: 'Vehicle inquiry.\nContact email: a@b.co',
    );

void main() {
  group('PDF text', () {
    test('unencodable characters never reach the PDF font', () {
      expect(pdfSafeText('Pearl — White “Edition” • 2021'), 'Pearl - White "Edition" - 2021');
      expect(pdfSafeText('Honda 🚗 Civic'), 'Honda Civic');
      expect(pdfSafeText(null), 'Not specified');
      expect(pdfSafeText('   '), 'Not specified');
      expect(pdfSafeText('😀'), 'Not specified');
    });

    test('sticker spec grid falls back to "Not specified" instead of a glyph box', () {
      final rows = Map.fromEntries(
          WindowStickerPdfService.specRows(_car()).map((r) => MapEntry(r.$1, r.$2)));
      expect(rows['Color'], 'Not specified');
      expect(rows['Inspection'], 'Not inspected');
      final withColor = Map.fromEntries(
          WindowStickerPdfService.specRows(_car(color: 'pearl_white', score: 9.2))
              .map((r) => MapEntry(r.$1, r.$2)));
      expect(withColor['Color'], 'Pearl White');
      expect(withColor['Inspection'], '9.2 / 10');
    });

    test('the sticker QR points at the customer app listing route', () {
      expect(customerListingUrl('car-1'), 'https://autoserve.app/vehicles/car-1');
    });

    testWidgets('sticker and monthly summary PDFs generate', (tester) async {
      await tester.runAsync(() async {
        final sticker = await const WindowStickerPdfService().generate(
          car: _car(color: 'White'),
          dealer: null,
          dealershipName: 'Capital Motors',
          carDetailUrl: customerListingUrl('car-1'),
        );
        expect(String.fromCharCodes(sticker.take(4)), '%PDF');

        final summary = await const ReportExportService().monthlySummaryPdf(
          dealerName: 'Capital Motors',
          metrics: const DashboardMetrics(
            totalVehicles: 12, availableVehicles: 8, reservedVehicles: 2, newLeadsToday: 1,
            soldVehicles: 9, soldThisMonth: 2, activeLeadsCount: 5, grossStockValue: 42000000,
            leadsThisMonth: 7,
            leadsByStage: {'new': 3, 'contacted': 2, 'test_drive_scheduled': 1, 'negotiating': 1,
                'closed_won': 4, 'closed_lost': 1},
          ),
          totalLeads: 12,
        );
        expect(String.fromCharCodes(summary.take(4)), '%PDF');
      });
    });
  });

  group('Lead SLA', () {
    final now = DateTime(2026, 10, 16, 12);

    test('a new lead goes stale at 24 hours, not before', () {
      expect(isStaleLead(_lead(createdAt: now.subtract(const Duration(hours: 23, minutes: 59))), now: now), isFalse);
      expect(isStaleLead(_lead(createdAt: now.subtract(const Duration(hours: 24))), now: now), isTrue);
    });

    test('moving the lead past "new" clears the warning', () {
      final old = now.subtract(const Duration(days: 3));
      expect(isStaleLead(_lead(createdAt: old, status: 'contacted'), now: now), isFalse);
      expect(isStaleLead(_lead(createdAt: old, status: 'closed_lost'), now: now), isFalse);
    });
  });

  group('Leads CSV', () {
    test('columns, vehicle titles, and stage labels', () {
      final csv = const ReportExportService().leadsCsv(
        [_lead(createdAt: DateTime(2026, 10, 1, 9, 5))],
        {'c1': '2021 Honda Civic'},
      );
      final lines = csv.split('\r\n');
      expect(lines.first, 'Lead Name,Phone,Vehicle,Stage,Source,Created Date,Notes');
      expect(lines[1], contains('2021 Honda Civic'));
      expect(lines[1], contains('New Inquiry'));
      expect(lines[1], contains('Vehicle inquiry. | Contact email: a@b.co'));
    });

    test('formula-looking cells are neutralised', () {
      expect(csvSafe('=HYPERLINK("http://evil")'), "'=HYPERLINK(\"http://evil\")");
      expect(csvSafe('@SUM(A1)'), "'@SUM(A1)");
      expect(csvSafe('+923001234567'), "'+923001234567");
      expect(csvSafe('Ali Khan'), 'Ali Khan');
    });

    test('bytes start with a UTF-8 BOM for Excel', () {
      final bytes = const ReportExportService().leadsCsvBytes([], {});
      expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
    });
  });
}

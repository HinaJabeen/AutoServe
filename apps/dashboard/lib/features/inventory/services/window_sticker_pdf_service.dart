// lib/features/inventory/services/window_sticker_pdf_service.dart
//
// 1-click printable window sticker (A4). Every string goes through
// [stickerText] (pdfSafeText): the built-in PDF font only encodes Latin-1,
// and anything else — e.g. the em dash once used for missing values —
// printed as a ☒ box.

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart'
    show QrPainter, QrVersions, QrErrorCorrectLevel, QrEyeStyle, QrDataModuleStyle;
import 'package:shared/shared.dart';

import '../../../core/pdf/pdf_text.dart';

const _notSpecified = pdfNotSpecified;

/// Latin-1-safe sticker text — see core/pdf/pdf_text.dart.
String stickerText(Object? value, {String fallback = _notSpecified}) =>
    pdfSafeText(value, fallback: fallback);

/// Public customer-app link for a listing — what the sticker's QR encodes.
/// `CUSTOMER_APP_URL` in the dashboard's .env overrides the base.
String customerListingUrl(String carId) {
  final fromEnv = dotenv.isInitialized ? dotenv.maybeGet('CUSTOMER_APP_URL')?.trim() : null;
  final base = (fromEnv == null || fromEnv.isEmpty) ? 'https://autoserve.app' : fromEnv;
  return '${base.replaceAll(RegExp(r'/+$'), '')}/vehicles/$carId';
}

String _titleCase(String s) => s
    .split(RegExp(r'[_\s]+'))
    .where((w) => w.isNotEmpty)
    .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
    .join(' ');

String _grouped(num n) => n
    .toStringAsFixed(0)
    .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

class WindowStickerPdfService {
  const WindowStickerPdfService();

  static const _brand = PdfColor.fromInt(0xFF0B1F3A);
  static const _accent = PdfColor.fromInt(0xFF0066FF);
  static const _muted = PdfColors.grey700;

  Future<Uint8List> _renderQr(String data) async {
    final painter = QrPainter(
      data: data,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      eyeStyle: const QrEyeStyle(color: ui.Color(0xFF000000)),
      dataModuleStyle: const QrDataModuleStyle(color: ui.Color(0xFF000000)),
    );
    const size = 600.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, const ui.Rect.fromLTWH(0, 0, size, size));
    canvas.drawRect(const ui.Rect.fromLTWH(0, 0, size, size),
        ui.Paint()..color = const ui.Color(0xFFFFFFFF));
    painter.paint(canvas, const ui.Size(size, size));
    final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// The car's first photo, or null if it can't be fetched — the sticker
  /// must still print without it.
  Future<pw.ImageProvider?> _loadPhoto(CarModel car) async {
    if (car.photoUrls.isEmpty) return null;
    try {
      return await networkImage(car.photoUrls.first).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Window sticker: photo unavailable ($e)');
      return null;
    }
  }

  @visibleForTesting
  static List<(String, String)> specRows(CarModel car) => [
        ('Year', stickerText(car.year)),
        ('Mileage', car.mileage == null ? _notSpecified : '${_grouped(car.mileage!)} km'),
        ('Transmission', stickerText(car.transmission == null ? null : _titleCase(car.transmission!))),
        ('Fuel Type', stickerText(car.fuelType == null ? null : _titleCase(car.fuelType!))),
        ('Condition', stickerText(car.condition == null ? null : _titleCase(car.condition!))),
        ('Color', stickerText(car.color == null ? null : _titleCase(car.color!))),
        ('Body Type', stickerText(car.specs['body_type'] == null ? null : _titleCase('${car.specs['body_type']}'))),
        ('Chassis No.', stickerText(car.chassisNumber)),
        ('Inspection',
            car.inspectionScore == null ? 'Not inspected' : '${car.inspectionScore!.toStringAsFixed(1)} / 10'),
        ('Stock ID', stickerText(car.id.length > 8 ? car.id.substring(0, 8).toUpperCase() : car.id)),
      ];

  Future<Uint8List> generate({
    required CarModel car,
    required DealershipModel? dealer,
    required String dealershipName,
    required String carDetailUrl,
  }) async {
    final doc = pw.Document(title: stickerText(car.displayTitle), author: 'AutoServe');
    final qr = pw.MemoryImage(await _renderQr(carDetailUrl));
    final photo = await _loadPhoto(car);

    final showroom = stickerText(dealer?.name ?? dealershipName, fallback: 'AutoServe Dealer');
    final contact = [
      if ((dealer?.phone ?? '').trim().isNotEmpty) 'Tel: ${stickerText(dealer!.phone)}',
      if ((dealer?.city ?? '').trim().isNotEmpty) stickerText(dealer!.city),
      if ((dealer?.address ?? '').trim().isNotEmpty) stickerText(dealer!.address),
    ].join('   |   ');

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _brand, width: 2.5),
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _header(showroom, contact),
              pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(stickerText(car.displayTitle),
                        style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: _brand)),
                    pw.SizedBox(height: 4),
                    pw.Text(stickerText(car.formattedPrice),
                        style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: _accent)),
                  ],
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(24, 18, 24, 0),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          if (photo != null) ...[
                            pw.ClipRRect(
                              horizontalRadius: 6,
                              verticalRadius: 6,
                              child: pw.Image(photo, height: 170, fit: pw.BoxFit.cover),
                            ),
                            pw.SizedBox(height: 14),
                          ],
                          _specGrid(car),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 20),
                    pw.Expanded(flex: 2, child: _qrPanel(qr)),
                  ],
                ),
              ),
              if (car.features.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: _features(car.features),
                ),
              pw.Spacer(),
              _footer(car),
            ],
          ),
        ),
      ),
    );

    return doc.save();
  }

  pw.Widget _header(String showroom, String contact) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: const pw.BoxDecoration(
          color: _brand,
          borderRadius: pw.BorderRadius.only(
              topLeft: pw.Radius.circular(8), topRight: pw.Radius.circular(8)),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('AutoServe',
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              pw.Text('VERIFIED DEALER LISTING',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey300, letterSpacing: 1.5)),
            ]),
            pw.Spacer(),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text(showroom,
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              if (contact.isNotEmpty)
                pw.Text(contact, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey200)),
            ]),
          ],
        ),
      );

  pw.Widget _specGrid(CarModel car) {
    final rows = specRows(car);
    final cells = <pw.TableRow>[];
    for (var i = 0; i < rows.length; i += 2) {
      final right = i + 1 < rows.length ? rows[i + 1] : ('', '');
      cells.add(pw.TableRow(
        decoration: pw.BoxDecoration(color: (i ~/ 2).isEven ? PdfColors.grey100 : PdfColors.white),
        children: [
          _cell(rows[i].$1, label: true),
          _cell(rows[i].$2),
          _cell(right.$1, label: true),
          _cell(right.$2),
        ],
      ));
    }
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.1),
        1: pw.FlexColumnWidth(1.4),
        2: pw.FlexColumnWidth(1.1),
        3: pw.FlexColumnWidth(1.4),
      },
      children: cells,
    );
  }

  pw.Widget _cell(String text, {bool label = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: pw.Text(text,
            style: label
                ? const pw.TextStyle(fontSize: 9, color: _muted)
                : pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
      );

  pw.Widget _qrPanel(pw.ImageProvider qr) => pw.Container(
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _accent, width: 1.5),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Image(qr, width: 150, height: 150),
            pw.SizedBox(height: 10),
            pw.Text('Scan to View Full Listing & Inspection on AutoServe',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _brand)),
            pw.SizedBox(height: 4),
            pw.Text('Photos, inspection report and direct WhatsApp contact',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 8, color: _muted)),
          ],
        ),
      );

  pw.Widget _features(List<String> features) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('FEATURES',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _muted, letterSpacing: 1)),
          pw.SizedBox(height: 6),
          pw.Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final f in features.take(18))
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(stickerText(f), style: const pw.TextStyle(fontSize: 9)),
                ),
            ],
          ),
        ],
      );

  pw.Widget _footer(CarModel car) {
    final now = DateTime.now();
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Row(children: [
        pw.Text('Prices and availability subject to change. Verify details with the dealer.',
            style: const pw.TextStyle(fontSize: 8, color: _muted)),
        pw.Spacer(),
        pw.Text('Printed ${now.day}/${now.month}/${now.year}',
            style: const pw.TextStyle(fontSize: 8, color: _muted)),
      ]),
    );
  }

  Future<void> printSticker({
    required CarModel car,
    required DealershipModel? dealer,
    required String dealershipName,
  }) async {
    final bytes = await generate(
      car: car,
      dealer: dealer,
      dealershipName: dealershipName,
      carDetailUrl: customerListingUrl(car.id),
    );
    await Printing.layoutPdf(
      name: 'Window sticker - ${stickerText(car.displayTitle)}',
      onLayout: (_) async => bytes,
    );
  }
}

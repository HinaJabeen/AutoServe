// lib/features/inventory/services/window_sticker_pdf_service.dart


import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart' show QrPainter, QrVersions, QrErrorCorrectLevel;
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:dashboard/features/inventory/models/car_model.dart';

class WindowStickerPdfService {
  const WindowStickerPdfService();

  /// Renders the given [carDetailUrl] (deep link to the customer-app listing)
  /// as a PNG so it can be embedded in the PDF.
  /// QrVersions.auto allows any length URL without throwing QrInputTooLongException.
  Future<Uint8List> _renderQr(String data) async {
    final painter = QrPainter(
      data: data,
      version: QrVersions.auto,  // ← FIX: auto-scales to fit URL length
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      color: const ui.Color(0xFF000000),
      emptyColor: const ui.Color(0xFFFFFFFF),
    );
    final image = await painter.toImage(300);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<Uint8List> generate({
    required CarModel car,
    required String dealershipName,
    required String carDetailUrl,
  }) async {
    final doc = pw.Document();
    final qrBytes = await _renderQr(carDetailUrl);
    final qrImage = pw.MemoryImage(qrBytes);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(dealershipName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Window Sticker', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(),
              pw.SizedBox(height: 12),
              pw.Text(car.displayTitle, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(car.formattedPrice, style: pw.TextStyle(fontSize: 20, color: PdfColors.blue800)),
              pw.SizedBox(height: 20),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(child: _specsColumn(car)),
                  pw.SizedBox(width: 20),
                  pw.Column(
                    children: [
                      pw.Image(qrImage, width: 120, height: 120),
                      pw.SizedBox(height: 6),
                      pw.Text('Scan for full listing', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
              if (car.features.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Text('Features', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: car.features
                      .map((f) => pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: PdfColors.grey400),
                              borderRadius: pw.BorderRadius.circular(4),
                            ),
                            child: pw.Text(f, style: const pw.TextStyle(fontSize: 9)),
                          ))
                      .toList(),
                ),
              ],
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  pw.Widget _specsColumn(CarModel car) {
    final rows = <MapEntry<String, String>>[
      MapEntry('Year', '${car.year}'),
      MapEntry('Mileage', car.mileage != null ? '${car.mileage} km' : '—'),
      MapEntry('Color', car.color ?? '—'),
      MapEntry('Transmission', car.transmission ?? '—'),
      MapEntry('Fuel Type', car.fuelType ?? '—'),
      MapEntry('Condition', car.condition ?? '—'),
    ];
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: rows
          .map((e) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Row(
                  children: [
                    pw.SizedBox(width: 110, child: pw.Text(e.key, style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 11))),
                    pw.Text(e.value, style: const pw.TextStyle(fontSize: 11)),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Future<void> printSticker({
    required CarModel car,
    required String dealershipName,
    required String carDetailUrl,
  }) async {
    final bytes = await generate(car: car, dealershipName: dealershipName, carDetailUrl: carDetailUrl);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }
}
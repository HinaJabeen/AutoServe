// apps/dashboard/lib/widgets/qr_code_button.dart

import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

class QRCodeButton extends StatelessWidget {
  const QRCodeButton({
    super.key,
    required this.vehicleId,
    required this.vehicleName,
  });

  final String vehicleId;
  final String vehicleName;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showQRDialog(context),
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            Icons.qr_code_2_rounded,
            size: AppDimensions.iconSizeM,
            color: Theme.of(context).primaryColor,
          ),
        ),
      ),
    );
  }

  void _showQRDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Vehicle QR Code',
          style: AppTextStyles.heading2.copyWith(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 16,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0A0D14) : Colors.white,
                borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
              child: _QRCodeDisplay(
                data: vehicleId,
                label: vehicleName,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Share this QR code with customers to view vehicle details',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                color: isDark ? Colors.white54 : Colors.black54,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: AppTextStyles.body.copyWith(
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
        ],
        backgroundColor: isDark ? const Color(0xFF000000) : Colors.white,
      ),
    );
  }
}

class _QRCodeDisplay extends StatelessWidget {
  const _QRCodeDisplay({
    required this.data,
    required this.label,
  });

  final String data;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            color: isDark ? Colors.white : Colors.black,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF000000) : Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: CustomPaint(
                painter: _SimpleQRPainter(
                  data: data,
                  fgColor: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: AppTextStyles.bodyBold.copyWith(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'ID: $data',
          style: AppTextStyles.caption.copyWith(
            color: isDark ? Colors.white54 : Colors.black54,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _SimpleQRPainter extends CustomPainter {
  _SimpleQRPainter({required this.data, required this.fgColor});

  final String data;
  final Color fgColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = fgColor;
    final cellSize = size.width / 25;

    for (int i = 0; i < data.length; i++) {
      final code = data.codeUnitAt(i);
      for (int bit = 0; bit < 8; bit++) {
        if ((code & (1 << bit)) != 0) {
          final x = ((i * 8 + bit) % 25) * cellSize;
          final y = ((i * 8 + bit) ~/ 25) * cellSize;
          canvas.drawRect(
            Rect.fromLTWH(x, y, cellSize - 1, cellSize - 1),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SimpleQRPainter oldDelegate) =>
      oldDelegate.data != data;
}
// apps/dashboard/lib/features/presentation/widgets/vehicle_qr_code.dart
//
// Reusable QR widget bridging the dealer dashboard to the customer-facing
// app. Payload uses a custom URI scheme (autoserve://vehicle/[ID]) rather
// than an https link so the customer app's OS-level deep link handler can
// intercept the scan directly, instead of routing through a browser first.

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared/shared.dart';

/// Builds the canonical deep-link payload for a vehicle QR code.
/// Kept as a single source of truth so both the widget and any future
/// caller (e.g. a share/export action) format the URI identically.
String vehicleDeepLink(String vehicleId) => 'autoserve://vehicle/$vehicleId';

// ---------------------------------------------------------------------------
// VehicleQRCode — the code itself, always on a solid white plate.
//
// The white backing is non-negotiable: this app renders on a dark navy
// surface, and QR scanners rely on strong quiet-zone contrast. Without a
// solid light plate behind the modules, phone cameras frequently fail to
// lock onto the code against a dark background.
// ---------------------------------------------------------------------------

class VehicleQRCode extends StatelessWidget {
  const VehicleQRCode({
    super.key,
    required this.vehicleId,
    this.size = 200,
    this.padding = 20,
  });

  final String vehicleId;
  final double size;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      child: QrImageView(
        data: vehicleDeepLink(vehicleId),
        version: QrVersions.auto,
        size: size,
        backgroundColor: Colors.white,
        // Generous quiet zone / error correction so a slightly worn print
        // or a glare off a phone screen still scans reliably.
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: AppColors.navyBackground,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: AppColors.navyBackground,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// VehicleQRDialog — glassmorphic modal wrapper around VehicleQRCode.
// Open with: showDialog(context: context, builder: (_) => VehicleQRDialog(vehicle: v));
// ---------------------------------------------------------------------------

class VehicleQRDialog extends StatelessWidget {
  const VehicleQRDialog({super.key, required this.vehicle});

  final VehicleModel vehicle;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 360,
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
        decoration: BoxDecoration(
          color: AppColors.navySurface.withOpacity(0.92),
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          border: Border.all(color: AppColors.pastelPink.withOpacity(0.22)),
          boxShadow: [
            BoxShadow(
              color: AppColors.pastelPink.withOpacity(0.16),
              blurRadius: 40,
              spreadRadius: -6,
            ),
            const BoxShadow(
              color: Colors.black54,
              blurRadius: 30,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Close button ─────────────────────────────────────────
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),

            // ── Vehicle identity ─────────────────────────────────────
            Text(
              vehicle.displayTitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.heading2.copyWith(color: Colors.white, fontSize: 17),
            ),
            const SizedBox(height: 4),
            Text(
              'Scan to view on the AutoServe app',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(color: Colors.white38, fontSize: 12),
            ),

            const SizedBox(height: AppDimensions.paddingL),

            // ── QR code, glowing pastel-pink halo around the white plate ──
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.pastelPink.withOpacity(0.28),
                    blurRadius: 32,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: VehicleQRCode(vehicleId: vehicle.id),
            ),

            const SizedBox(height: AppDimensions.paddingM),

            // ── Raw payload, for support/debugging visibility ─────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                border: Border.all(color: AppColors.navyBorder),
              ),
              child: Text(
                vehicleDeepLink(vehicle.id),
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white30,
                  fontSize: 10.5,
                  fontFamily: 'monospace',
                ),
              ),
            ),

            const SizedBox(height: AppDimensions.paddingL),

            SizedBox(
              width: double.infinity,
              height: 42,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.navyBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                  ),
                ),
                child: Text('Close', style: AppTextStyles.body.copyWith(color: Colors.white60, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

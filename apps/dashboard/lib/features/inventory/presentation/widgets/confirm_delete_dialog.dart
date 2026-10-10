// lib/features/inventory/presentation/widgets/confirm_delete_dialog.dart

import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

/// Shows a blocking confirmation before any destructive delete.
/// Returns true only if the user explicitly confirmed.
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.navySurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusL)),
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 22),
          const SizedBox(width: 10),
          Text(title, style: AppTextStyles.heading2.copyWith(color: Colors.white, fontSize: 17)),
        ],
      ),
      content: Text(message, style: AppTextStyles.body.copyWith(color: Colors.white60, fontSize: 13.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Cancel', style: AppTextStyles.body.copyWith(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusS)),
          ),
          child: Text(confirmLabel, style: AppTextStyles.button.copyWith(color: Colors.white)),
        ),
      ],
    ),
  );
  return result ?? false;
}

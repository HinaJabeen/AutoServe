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
  final p = context.palette;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    // `showDialog` defaults to `useRootNavigator: true`, pushing this route
    // onto the app's root Navigator. Popping must go through THIS builder's
    // own `dialogContext` — using the outer `context` instead finds the
    // nearest enclosing Navigator (the GoRouter ShellRoute's nested one under
    // this app's router setup), which pops the underlying page out from under
    // GoRouter's own state instead of closing the dialog, desyncing the route
    // stack and blanking the screen.
    builder: (dialogContext) => AlertDialog(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusL)),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: p.error, size: 22),
          const SizedBox(width: 10),
          Flexible(
            child: Text(title,
                style: AppTextStyles.heading2.copyWith(color: p.textPrimary, fontSize: 17)),
          ),
        ],
      ),
      content: Text(message,
          style: AppTextStyles.body.copyWith(color: p.textSecondary, fontSize: 13.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text('Cancel', style: AppTextStyles.body.copyWith(color: p.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: p.error,
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

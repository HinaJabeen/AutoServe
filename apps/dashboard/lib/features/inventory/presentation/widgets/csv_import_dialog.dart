// lib/features/inventory/presentation/widgets/csv_import_dialog.dart

import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import 'package:dashboard/features/inventory/services/inventory_csv_service.dart';
import 'package:dashboard/features/inventory/providers/inventory_providers.dart';

class CsvImportDialog extends ConsumerStatefulWidget {
  const CsvImportDialog({super.key});
  @override
  ConsumerState<CsvImportDialog> createState() => _CsvImportDialogState();
}

class _CsvImportDialogState extends ConsumerState<CsvImportDialog> {
  final _csvService = InventoryCsvService();
  CsvImportResult? _result;
  bool _isImporting = false;
  String? _fileError;

  Future<void> _pickFile() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    final bytes = picked?.files.single.bytes;
    if (bytes == null) return;
    try {
      final text = utf8.decode(bytes);
      setState(() {
        _result = _csvService.import(text);
        _fileError = null;
      });
    } catch (e) {
      setState(() => _fileError = 'Could not read file: $e');
    }
  }

  Future<void> _confirmImport() async {
    final result = _result;
    final service = ref.read(inventoryServiceProvider);
    if (result == null || service == null || result.validCars.isEmpty) return;

    setState(() => _isImporting = true);
    var failures = 0;
    for (final car in result.validCars) {
      try {
        await service.createCar(car);
      } catch (_) {
        failures++;
      }
    }
    setState(() => _isImporting = false);
    ref.read(inventoryListProvider.notifier).refresh();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Imported ${result.validCars.length - failures} of ${result.validCars.length} vehicles.'),
      ));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Dialog(
      backgroundColor: AppColors.navySurface,
      child: Container(
        width: 560,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bulk Import Inventory (CSV)', style: AppTextStyles.heading2.copyWith(color: Colors.white, fontSize: 17)),
            const SizedBox(height: 6),
            Text('Required columns: make, model, year, price, status.', style: AppTextStyles.caption.copyWith(color: Colors.white38)),
            const SizedBox(height: AppDimensions.paddingM),
            OutlinedButton.icon(onPressed: _pickFile, icon: const Icon(Icons.upload_file_rounded), label: const Text('Choose CSV file')),
            if (_fileError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_fileError!, style: TextStyle(color: AppColors.error))),
            if (result != null) ...[
              const SizedBox(height: AppDimensions.paddingM),
              Text('${result.validCars.length} valid rows, ${result.errors.length} errors', style: AppTextStyles.body.copyWith(color: Colors.white70)),
              if (result.errors.isNotEmpty)
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: result.errors.map((e) => Text(e.toString(), style: TextStyle(color: AppColors.error, fontSize: 11))).toList(),
                  ),
                ),
            ],
            const SizedBox(height: AppDimensions.paddingL),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: (result == null || result.validCars.isEmpty || _isImporting) ? null : _confirmImport,
                  child: _isImporting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text('Import ${result?.validCars.length ?? 0} vehicles'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

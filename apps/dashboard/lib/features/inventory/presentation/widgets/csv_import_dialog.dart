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
  List<String> _importFailures = const [];

  Future<void> _pickFile() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    final bytes = picked?.files.single.bytes;
    if (bytes == null) return;
    try {
      final text = utf8.decode(bytes);
      setState(() {
        _result = _csvService.import(text);
        _fileError = null;
        _importFailures = const [];
      });
    } catch (e) {
      setState(() => _fileError = 'Could not read file: $e');
    }
  }

  Future<void> _confirmImport() async {
    final result = _result;
    final service = ref.read(inventoryServiceProvider);
    if (result == null || service == null || result.validCars.isEmpty) return;

    setState(() {
      _isImporting = true;
      _importFailures = const [];
    });
    final failures = <String>[];
    for (final car in result.validCars) {
      try {
        await service.createCar(car);
      } catch (e) {
        final line = '${car.year} ${car.make} ${car.model}: $e';
        debugPrint('CSV import failed — $line');
        failures.add(line);
      }
    }
    ref.read(inventoryListProvider.notifier).refresh();
    if (!mounted) return;

    final imported = result.validCars.length - failures.length;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Imported $imported of ${result.validCars.length} vehicles.'),
    ));
    if (failures.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    // Keep the dialog open so the reasons are readable. The rows that did
    // import are cleared so a second click can't insert them twice.
    setState(() {
      _isImporting = false;
      _importFailures = failures;
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final p = context.palette;
    return Dialog(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      child: Container(
        width: 560,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bulk Import Inventory (CSV)', style: AppTextStyles.heading2.copyWith(color: p.textPrimary, fontSize: 17)),
            const SizedBox(height: 6),
            Text('Required columns: make, model, year, price, status.', style: AppTextStyles.caption.copyWith(color: p.textSecondary)),
            const SizedBox(height: AppDimensions.paddingM),
            OutlinedButton.icon(onPressed: _pickFile, icon: const Icon(Icons.upload_file_rounded), label: const Text('Choose CSV file')),
            if (_fileError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_fileError!, style: TextStyle(color: p.error))),
            if (result != null) ...[
              const SizedBox(height: AppDimensions.paddingM),
              Text('${result.validCars.length} valid rows, ${result.errors.length} errors', style: AppTextStyles.body.copyWith(color: p.textPrimary)),
              if (result.ignoredColumns.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Not imported — unrecognised column(s): ${result.ignoredColumns.join(', ')}. '
                    'Rename them to match: mileage, color, transmission, fuel_type, condition, body_type.',
                    style: AppTextStyles.caption.copyWith(color: p.warning),
                  ),
                ),
              if (result.errors.isNotEmpty)
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: result.errors.map((e) => Text(e.toString(), style: TextStyle(color: p.error, fontSize: 11))).toList(),
                  ),
                ),
            ],
            if (_importFailures.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.paddingM),
              Text('${_importFailures.length} vehicle(s) were rejected by the database:',
                  style: AppTextStyles.body.copyWith(color: p.textPrimary)),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: _importFailures
                      .map((f) => SelectableText(f, style: TextStyle(color: p.error, fontSize: 11)))
                      .toList(),
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

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Asks where to save [bytes]; returns false if the user cancelled.
Future<bool> saveBytes(Uint8List bytes, String filename, String mimeType) async {
  final path = await FilePicker.platform.saveFile(fileName: filename, bytes: bytes);
  if (path == null) return false;
  // Desktop returns a path without writing; mobile writes `bytes` itself.
  final file = File(path);
  if (!await file.exists() || await file.length() == 0) {
    await file.writeAsBytes(bytes);
  }
  return true;
}

// lib/core/cnic.dart
//
// Pakistani CNIC: 13 digits written XXXXX-XXXXXXX-X. The DB enforces the
// same pattern (dealer_verifications.owner_cnic check constraint).

import 'package:flutter/services.dart';

final _cnicPattern = RegExp(r'^\d{5}-\d{7}-\d$');

/// Formats any input as XXXXX-XXXXXXX-X while typing; ignores non-digits.
class CnicInputFormatter extends TextInputFormatter {
  static String format(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final d = digits.length > 13 ? digits.substring(0, 13) : digits;
    final b = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i == 5 || i == 12) b.write('-');
      b.write(d[i]);
    }
    return b.toString();
  }

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = format(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

String? validateCnic(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Enter the CNIC number';
  if (!_cnicPattern.hasMatch(v)) return 'Use the format 12345-1234567-1';
  return null;
}

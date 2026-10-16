// lib/core/pdf/pdf_text.dart
//
// The `pdf` package's built-in fonts (Helvetica etc.) can only encode
// Latin-1. Any other character — em dash, curly quotes, bullets, emoji,
// Urdu — prints as a ☒ box. Run every string bound for a PDF through here.

const pdfNotSpecified = 'Not specified';

/// Latin-1-safe text; blank/null → [fallback].
String pdfSafeText(Object? value, {String fallback = pdfNotSpecified}) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) return fallback;
  const replacements = {
    '—': '-', '–': '-', '‒': '-', '−': '-',
    '‘': "'", '’': "'", '“': '"', '”': '"',
    '•': '-', '·': '-', '…': '...', ' ': ' ',
  };
  final buffer = StringBuffer();
  for (final rune in raw.runes) {
    final ch = String.fromCharCode(rune);
    final mapped = replacements[ch];
    if (mapped != null) {
      buffer.write(mapped);
    } else if (rune <= 0xFF) {
      buffer.write(ch);
    }
    // Anything else is dropped rather than printed as a box.
  }
  final cleaned = buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  return cleaned.isEmpty ? fallback : cleaned;
}

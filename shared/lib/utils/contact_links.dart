/// Phone/WhatsApp deep links shared by the dashboard (lead dialog) and the
/// customer app (dealer contact). Building the Uri lives here; launching it
/// stays in each app.
class ContactLinks {
  ContactLinks._();

  /// Country code assumed for numbers written in local format ("0300…").
  /// AutoServe lists prices in PKR, so local numbers are Pakistani.
  static const defaultCountryCode = '92';

  /// Digits in international format without '+', or null if [raw] can't be
  /// a phone number. "0300-1234567" → "923001234567";
  /// "+92 300 1234567" / "0092300…" → "92300…".
  static String? internationalDigits(String? raw) {
    if (raw == null) return null;
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('00')) {
      digits = digits.substring(2);
    } else if (digits.startsWith('0')) {
      digits = '$defaultCountryCode${digits.substring(1)}';
    }
    return digits.length >= 8 && digits.length <= 15 ? digits : null;
  }

  static Uri? call(String? phone) {
    final digits = internationalDigits(phone);
    return digits == null ? null : Uri(scheme: 'tel', path: '+$digits');
  }

  static Uri? whatsApp(String? phone, {String? message}) {
    final digits = internationalDigits(phone);
    if (digits == null) return null;
    return Uri.https('wa.me', '/$digits', {
      if (message != null && message.isNotEmpty) 'text': message,
    });
  }
}

// lib/core/validators.dart
//
// Form-field validators (return null when valid, matching
// `TextFormField.validator`). Shared by the auth screens and the lead forms.

class Validators {
  Validators._();

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');
  static final _phone = RegExp(r'^\+?[0-9\s\-()]{7,20}$');

  static String? fullName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your full name';
    if (v.length < 2) return 'That name looks too short';
    if (v.length > 120) return 'That name is too long';
    return null;
  }

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your email';
    if (!_email.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  static String? phone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your phone number';
    final digits = v.replaceAll(RegExp(r'\D'), '').length;
    if (!_phone.hasMatch(v) || digits < 7 || digits > 15) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  /// Sign-in: only checks something was typed — the server decides the rest.
  static String? passwordRequired(String? value) =>
      (value == null || value.isEmpty) ? 'Enter your password' : null;

  /// Sign-up: catches the obvious weak cases before the round trip. Supabase
  /// still enforces its own policy; `friendlyAuthError` covers a rejection.
  static String? newPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Create a password';
    if (v.length < 8) return 'Use at least 8 characters';
    if (!v.contains(RegExp(r'[A-Za-z]')) || !v.contains(RegExp(r'[0-9]'))) {
      return 'Include at least one letter and one number';
    }
    return null;
  }
}

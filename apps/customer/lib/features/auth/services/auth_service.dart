// lib/features/auth/services/auth_service.dart
//
// Thin wrapper over Supabase Auth + the `profiles` table. All Supabase calls
// for sign-in/sign-up live here (never in a widget) — AuthNotifier turns the
// results into UI state.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/customer_profile.dart';

class AuthService {
  AuthService(this._client);
  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<User?> signIn({required String email, required String password}) async {
    final res = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return res.user;
  }

  /// `full_name`/`phone` travel as auth user metadata; the DB's
  /// `handle_new_user()` trigger copies them into the new `profiles` row in
  /// the same transaction that creates the auth user, so the profile exists
  /// by the time this returns. The role is assigned server-side and can't be
  /// set from here.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName, 'phone': phone},
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  /// The signed-in user's own `profiles` row (RLS only ever returns that
  /// one), or null if it doesn't exist.
  Future<CustomerProfile?> fetchProfile(User user) async {
    final row = await _client
        .from('profiles')
        .select('id, full_name, phone, role')
        .eq('id', user.id)
        .maybeSingle();
    if (row == null) return null;
    return CustomerProfile.fromJson(row, email: user.email ?? '');
  }

  /// True when [userId] applied for a dealership through this app
  /// (`dealers.applicant_user_id`). Any failure — including the verification
  /// migration not being applied yet — counts as false.
  Future<bool> isSelfRegisteredDealer(String userId) async {
    try {
      final row = await _client
          .from('dealers')
          .select('id')
          .eq('applicant_user_id', userId)
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }
}

const emailAlreadyRegisteredMessage =
    'An account with this email already exists. Try signing in instead.';

/// Shown (as a SnackBar) when Supabase Auth throttles sign-in/sign-up.
///
/// Debug builds get the developer-facing hint: while testing, the limit that
/// actually trips is almost always the confirmation-email quota of
/// Supabase's built-in mail sender (a few emails per hour for the whole
/// project), and the fix is on the Supabase side. Release builds get wording
/// meant for a real customer, who can do nothing about project settings.
const rateLimitMessage = kDebugMode
    ? 'Rate limit reached. Please use a new dummy email or disable Email '
        'Confirmations in Supabase.'
    : 'Too many attempts. Please wait a few minutes and try again.';

/// Whether [error] is Supabase Auth refusing the request for being too
/// frequent (HTTP 429 — request, email-send or SMS-send limits).
bool isRateLimitError(Object error) {
  if (error is! AuthException) return false;
  const codes = {
    'over_request_rate_limit',
    'over_email_send_rate_limit',
    'over_sms_send_rate_limit',
  };
  if (codes.contains(error.code) || error.statusCode == '429') return true;
  final message = error.message.toLowerCase();
  return message.contains('rate limit') ||
      message.contains('too many requests') ||
      // "For security purposes, you can only request this after N seconds."
      message.contains('you can only request this after');
}

/// Turns a Supabase Auth failure into a sentence a customer can act on.
String friendlyAuthError(Object error) {
  if (isRateLimitError(error)) return rateLimitMessage;
  if (error is AuthWeakPasswordException) {
    return _weakPasswordMessage(error.reasons);
  }
  if (error is AuthRetryableFetchException) {
    return "Can't reach AutoServe right now. Check your connection and try again.";
  }
  if (error is TimeoutException) {
    return 'That took too long. Check your connection and try again.';
  }
  if (error is! AuthException) {
    return 'Something went wrong. Please try again.';
  }

  final message = error.message.toLowerCase();
  switch (error.code) {
    case 'invalid_credentials':
      return 'Incorrect email or password.';
    case 'email_not_confirmed':
      return 'Please confirm your email first — check your inbox for the link we sent.';
    case 'user_already_exists':
    case 'email_exists':
      return emailAlreadyRegisteredMessage;
    case 'weak_password':
      return _weakPasswordMessage(const []);
    case 'email_address_invalid':
    case 'validation_failed':
      return "That email address doesn't look right. Please check it.";
    case 'signup_disabled':
      return 'New sign-ups are currently closed.';
    case 'user_banned':
      return 'This account has been suspended. Please contact AutoServe support.';
  }

  // Older servers / edge paths that don't send an error code.
  if (message.contains('invalid login') || message.contains('invalid credentials')) {
    return 'Incorrect email or password.';
  }
  if (message.contains('email not confirmed')) {
    return 'Please confirm your email first — check your inbox for the link we sent.';
  }
  if (message.contains('already registered') || message.contains('already exists')) {
    return emailAlreadyRegisteredMessage;
  }
  if (message.contains('password') &&
      (message.contains('weak') || message.contains('at least') || message.contains('should be'))) {
    return _weakPasswordMessage(const []);
  }
  if (message.contains('failed to fetch') ||
      message.contains('failed host lookup') ||
      message.contains('clientexception')) {
    return "Can't reach AutoServe right now. Check your connection and try again.";
  }
  return error.message;
}

String _weakPasswordMessage(List<String> reasons) {
  if (reasons.contains('pwned')) {
    return 'That password has appeared in a data breach. Please choose a different one.';
  }
  if (reasons.contains('characters')) {
    return 'That password is too weak. Mix upper- and lower-case letters, numbers and symbols.';
  }
  return 'That password is too weak. Use at least 8 characters, mixing letters and numbers.';
}

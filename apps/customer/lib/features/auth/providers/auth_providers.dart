// lib/features/auth/providers/auth_providers.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent, AuthState, User;

import '../../saved/providers/saved_cars_providers.dart';
import '../models/customer_profile.dart';
import '../services/auth_service.dart';

// ── State ────────────────────────────────────────────────────────────────────

enum AuthStatus {
  initial, // app just started — restoring a stored session, if any
  unauthenticated,
  authenticated,
}

// Named CustomerAuthState because supabase_flutter exports its own AuthState.
class CustomerAuthState {
  const CustomerAuthState({
    this.status = AuthStatus.initial,
    this.profile,
    this.isSubmitting = false,
    this.errorMessage,
    this.noticeMessage,
    this.snackMessage,
  });

  final AuthStatus status;
  final CustomerProfile? profile; // non-null exactly when authenticated
  final bool isSubmitting; // a sign-in / sign-up request is in flight
  final String? errorMessage; // shown as a red banner on the auth screens
  final String? noticeMessage; // neutral banner, e.g. "confirm your email"
  final String? snackMessage; // transient SnackBar (rate limits) — see AuthScaffold

  bool get isAuthenticated => status == AuthStatus.authenticated;
}

enum SignUpResult { signedIn, confirmationRequired, failed }

// ── Notifier ─────────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<CustomerAuthState> {
  AuthNotifier(this._ref, this._service) : super(const CustomerAuthState()) {
    _init();
  }

  final Ref _ref;
  final AuthService _service;
  StreamSubscription<AuthState>? _sub;

  // True while this notifier is itself driving a sign-in/sign-up/restore, so
  // the auth-event listener doesn't resolve the same profile a second time.
  bool _busy = false;
  bool _signingOut = false;

  static const _unauthenticated =
      CustomerAuthState(status: AuthStatus.unauthenticated);

  // Supabase's HTTP client has no timeout of its own; without one a stalled
  // connection would leave the button (or the splash screen) spinning forever.
  static const _requestTimeout = Duration(seconds: 20);

  /// The signed-out state for a failed sign-in/sign-up: always clears
  /// `isSubmitting`. Rate limits surface as a SnackBar, everything else as
  /// the inline error banner.
  static CustomerAuthState _failure(Object error) {
    if (kDebugMode) debugPrint('AuthNotifier: auth request failed — $error');
    final message = friendlyAuthError(error);
    return isRateLimitError(error)
        ? CustomerAuthState(
            status: AuthStatus.unauthenticated, snackMessage: message)
        : CustomerAuthState(
            status: AuthStatus.unauthenticated, errorMessage: message);
  }

  /// Runs in the `finally` of signIn/signUp: whatever happened above, the
  /// form must not be left in its loading state.
  void _endSubmit() {
    _busy = false;
    if (mounted && state.isSubmitting) state = _unauthenticated;
  }

  // ── Bootstrap ───────────────────────────────────────────────────────────────

  Future<void> _init() async {
    _sub = _service.authStateChanges.listen(_onAuthEvent);

    final user = _service.currentUser;
    if (user == null) {
      state = _unauthenticated;
      return;
    }
    _busy = true;
    try {
      await _resolveProfile(user);
    } finally {
      _busy = false;
    }
  }

  void _onAuthEvent(AuthState data) {
    switch (data.event) {
      case AuthChangeEvent.signedOut:
        // Not authenticated → signOut()/_deny() already put the right state
        // (and message) in place; don't overwrite it.
        if (!state.isAuthenticated) break;
        _clearUserCaches();
        state = CustomerAuthState(
          status: AuthStatus.unauthenticated,
          // Not our own signOut() → the refresh token was revoked/expired.
          noticeMessage:
              _signingOut ? null : 'Your session expired. Please sign in again.',
        );

      case AuthChangeEvent.signedIn:
        // Sign-ins this notifier didn't start itself — e.g. the app being
        // opened from an email-confirmation link.
        final user = data.session?.user;
        if (user == null || _busy || state.isAuthenticated) break;
        _busy = true;
        _resolveProfile(user).whenComplete(() => _busy = false);

      default:
        break;
    }
  }

  // ── Sign in / sign up ───────────────────────────────────────────────────────

  Future<void> signIn({required String email, required String password}) async {
    if (state.isSubmitting) return;
    state = const CustomerAuthState(
        status: AuthStatus.unauthenticated, isSubmitting: true);
    _busy = true;
    try {
      final user = await _service
          .signIn(email: email.trim(), password: password)
          .timeout(_requestTimeout);
      if (user == null) {
        state = const CustomerAuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Sign-in failed. Please check your details and try again.',
        );
        return;
      }
      await _resolveProfile(user);
    } catch (e) {
      state = _failure(e);
    } finally {
      _endSubmit();
    }
  }

  Future<SignUpResult> signUp({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) async {
    if (state.isSubmitting) return SignUpResult.failed;
    state = const CustomerAuthState(
        status: AuthStatus.unauthenticated, isSubmitting: true);
    _busy = true;
    try {
      final cleanEmail = email.trim();
      final res = await _service
          .signUp(
            email: cleanEmail,
            password: password,
            fullName: fullName.trim(),
            phone: phone.trim(),
          )
          .timeout(_requestTimeout);
      final user = res.user;

      // With email confirmation on, Supabase doesn't raise an error for an
      // address that's already registered (that would reveal which emails
      // have accounts) — it returns a decoy user with no identities instead.
      if (user == null || (user.identities?.isEmpty ?? false)) {
        state = const CustomerAuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: emailAlreadyRegisteredMessage,
        );
        return SignUpResult.failed;
      }

      // No session yet → the project requires the email to be confirmed
      // before the first sign-in.
      if (res.session == null) {
        state = CustomerAuthState(
          status: AuthStatus.unauthenticated,
          noticeMessage:
              'Almost there — we sent a confirmation link to $cleanEmail. '
              'Open it, then sign in.',
        );
        return SignUpResult.confirmationRequired;
      }

      await _resolveProfile(user);
      return state.isAuthenticated ? SignUpResult.signedIn : SignUpResult.failed;
    } catch (e) {
      state = _failure(e);
      return SignUpResult.failed;
    } finally {
      _endSubmit();
    }
  }

  // ── Role resolution ─────────────────────────────────────────────────────────

  /// Loads the `profiles` row and decides whether this account may use the
  /// customer app. The role comes from the database (a trigger-maintained
  /// mirror of dealer_staff/admin_users), never from client-held metadata.
  Future<void> _resolveProfile(User user) async {
    final CustomerProfile? profile;
    try {
      profile = await _service.fetchProfile(user).timeout(_requestTimeout);
    } catch (e) {
      // Network failure, or the profiles migration hasn't been applied.
      // Don't end the Supabase session over something transient — the next
      // launch (or sign-in) simply tries again.
      if (kDebugMode) debugPrint('AuthNotifier: could not load profile — $e');
      state = const CustomerAuthState(
        status: AuthStatus.unauthenticated,
        errorMessage:
            "We couldn't load your profile. Check your connection and try again.",
      );
      return;
    }

    if (profile == null) {
      await _deny("We couldn't find a customer profile for this account. "
          'Please contact AutoServe support.');
      return;
    }
    if (!profile.isCustomer) {
      await _deny(profile.role == ProfileRole.admin
          ? "This is an AutoServe admin account, so it can't be used in the "
              'customer app.'
          : 'This is a dealer account. The customer app is for buyers — '
              'please sign in on the AutoServe Dealer Dashboard instead.');
      return;
    }

    state = CustomerAuthState(status: AuthStatus.authenticated, profile: profile);
  }

  /// Ends the session and sends the user back to /login with [message].
  /// State is set *before* signing out so the resulting `signedOut` event
  /// (see [_onAuthEvent]) finds it in place and leaves the message alone.
  Future<void> _deny(String message) async {
    state = CustomerAuthState(
      status: AuthStatus.unauthenticated,
      errorMessage: message,
    );
    try {
      await _service.signOut();
    } catch (e) {
      if (kDebugMode) debugPrint('AuthNotifier: sign-out after deny failed — $e');
    }
  }

  // ── Sign out ────────────────────────────────────────────────────────────────

  /// Returns null on success, or a message to show. On failure (offline) the
  /// stored session is still there, so the user stays signed in rather than
  /// being shown a login screen they'd bounce straight back out of on the
  /// next launch.
  Future<String?> signOut() async {
    if (_signingOut) return null;
    _signingOut = true;
    try {
      await _service.signOut();
      // The signedOut event normally gets here first; this covers it running late.
      if (state.isAuthenticated) {
        _clearUserCaches();
        state = _unauthenticated;
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('AuthNotifier: sign-out failed — $e');
      return "Couldn't sign out. Check your connection and try again.";
    } finally {
      _signingOut = false;
    }
  }

  /// Per-user in-memory state that must not carry over to whoever signs in
  /// next on this device. Add any new per-user provider here.
  void _clearUserCaches() {
    _ref.invalidate(savedCarsProvider);
  }

  void clearMessages() {
    if (state.errorMessage == null &&
        state.noticeMessage == null &&
        state.snackMessage == null) {
      return;
    }
    state = CustomerAuthState(
      status: state.status,
      profile: state.profile,
      isSubmitting: state.isSubmitting,
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

// ── Providers ────────────────────────────────────────────────────────────────

final authServiceProvider =
    Provider<AuthService>((ref) => AuthService(SupabaseService.client));

final authProvider = StateNotifierProvider<AuthNotifier, CustomerAuthState>(
    (ref) => AuthNotifier(ref, ref.read(authServiceProvider)));

final currentProfileProvider = Provider<CustomerProfile?>(
    (ref) => ref.watch(authProvider.select((s) => s.profile)));

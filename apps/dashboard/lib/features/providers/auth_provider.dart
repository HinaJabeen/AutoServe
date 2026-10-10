// apps/dashboard/lib/features/providers/auth_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Dev bypass — set false before shipping ───────────────────────────────────
const bool _kDevMode = false;

// ── Enums ────────────────────────────────────────────────────────────────────

enum AppRole { admin, dealerOwner, staff, none }

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  passwordRecovery, // Supabase reset-link clicked — show /update-password
  requiresPasswordChange, // first-login forced change flag in DB
  error,
}

// ── State ────────────────────────────────────────────────────────────────────

class AuthState {
  const AuthState({
    this.status = AuthStatus.initial,
    this.role = AppRole.none,
    this.userId,
    this.dealershipId,
    this.displayName,
    this.errorMessage,
    this.sessionExpired = false,
  });

  final AuthStatus status;
  final AppRole role;
  final String? userId;
  final String? dealershipId;
  final String? displayName;
  final String? errorMessage;
  final bool sessionExpired; // triggers "Session expired" snackbar in router

  bool get isAuthenticated => status == AuthStatus.authenticated;

  String get homeRoute {
    switch (role) {
      case AppRole.admin:       return '/admin/overview';
      case AppRole.dealerOwner:
      case AppRole.staff:       return '/home';
      case AppRole.none:        return '/login';
    }
  }

  AuthState copyWith({
    AuthStatus? status, AppRole? role, String? userId,
    String? dealershipId, String? displayName,
    String? errorMessage, bool? sessionExpired,
  }) => AuthState(
    status: status ?? this.status,
    role: role ?? this.role,
    userId: userId ?? this.userId,
    dealershipId: dealershipId ?? this.dealershipId,
    displayName: displayName ?? this.displayName,
    errorMessage: errorMessage,
    sessionExpired: sessionExpired ?? this.sessionExpired,
  );
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthState()) { _init(); }

  final Ref _ref;
  SupabaseClient get _c => Supabase.instance.client;

  // ── Bootstrap ───────────────────────────────────────────────────────────────

  Future<void> _init() async {
    if (_kDevMode) { _setDev(); return; }

    // Global auth state listener — catches passwordRecovery deep links and
    // token expiry events fired by Supabase's own refresh cycle.
    _c.auth.onAuthStateChange.listen((data) {
      switch (data.event) {
        case AuthChangeEvent.passwordRecovery:
          // Supabase fires this when the user clicks a reset link.
          // GoRouter picks up the state change via refreshListenable and
          // redirects to /update-password automatically.
          state = state.copyWith(status: AuthStatus.passwordRecovery);
          break;

        case AuthChangeEvent.signedOut:
          // Fired when refresh token expires server-side or signOut() is called.
          final wasAuthenticated = state.isAuthenticated;
          state = AuthState(
            status: AuthStatus.unauthenticated,
            sessionExpired: wasAuthenticated, // true = was kicked out, not manual logout
          );
          break;

        case AuthChangeEvent.tokenRefreshed:
          // Session renewed — clear any stale expiry flag.
          if (state.sessionExpired) {
            state = state.copyWith(sessionExpired: false);
          }
          break;

        case AuthChangeEvent.signedIn:
          // Handled by signIn() — no duplicate action needed here.
          break;

        default:
          break;
      }
    });

    final session = _c.auth.currentSession;
    if (session == null) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }
    await _resolveRole(session.user);
  }

  void _setDev() => state = const AuthState(
    status: AuthStatus.authenticated, role: AppRole.dealerOwner,
    userId: 'dev-user-001', displayName: 'Dev Dealer',
  );

  // ── Sign in ──────────────────────────────────────────────────────────────────

  Future<void> signIn({required String email, required String password}) async {
    if (_kDevMode) {
      state = state.copyWith(status: AuthStatus.loading);
      await Future.delayed(const Duration(milliseconds: 400));
      _setDev();
      return;
    }

    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final res = await _c.auth.signInWithPassword(
          email: email.trim(), password: password);
      final u = res.user;
      if (u == null) {
        state = state.copyWith(status: AuthStatus.error,
            errorMessage: 'Login failed. Please check your credentials.');
        return;
      }
      await _resolveRole(u);
    } on AuthException catch (e) {
      state = state.copyWith(status: AuthStatus.error,
          errorMessage: _friendly(e.message));
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error,
          errorMessage: 'Unexpected error: $e');
    }
  }

  // ── Role resolution ──────────────────────────────────────────────────────────

  Future<void> _resolveRole(User u) async {
    if (kDebugMode) print('╔ AUTH user_id=${u.id} email=${u.email}');
    try {
      // 1. dealer_staff (primary)
      final staff = await _c.from('dealer_staff').select()
          .eq('user_id', u.id).maybeSingle();
      if (kDebugMode) print('║ dealer_staff=$staff');

      if (staff != null) {
        final sRole   = staff['role']      as String? ?? '';
        final sStatus = staff['status']    as String? ?? 'active';
        final dealer  = staff['dealer_id'] as String?;
        final name    = staff['full_name'] as String?;
        final needsPwChange = (staff['requires_password_change'] as bool?) ?? false;

        if (sStatus == 'deactivated') {
          await _deny('Your account has been deactivated. Contact your admin.');
          return;
        }

        final role = sRole == 'owner' ? AppRole.dealerOwner : AppRole.staff;

        // First-login forced password change
        if (needsPwChange) {
          state = AuthState(
            status: AuthStatus.requiresPasswordChange,
            role: role, userId: u.id,
            dealershipId: dealer, displayName: name,
          );
          return;
        }

        state = AuthState(
          status: AuthStatus.authenticated, role: role,
          userId: u.id, dealershipId: dealer, displayName: name,
        );
        if (kDebugMode) print('✅ dealer_staff role=$sRole');
        return;
      }

      // 2. users fallback
      final uRow = await _c.from('users').select()
          .eq('id', u.id).maybeSingle();
      if (kDebugMode) print('║ users=$uRow');

      if (uRow != null) {
        final rawRole = uRow['role'] as String?;
        final active  = (uRow['is_active'] as bool?) ??
            ((uRow['status'] as String?) == 'active');
        final dealer  = uRow['dealership_id'] as String?;
        final name    = (uRow['full_name'] ?? uRow['name']) as String?;
        final needsPwChange = (uRow['requires_password_change'] as bool?) ?? false;

        const ok = {'admin', 'dealer', 'staff'};
        if (rawRole == null || !ok.contains(rawRole)) {
          await _deny('Access denied. Dashboard is for dealership staff only.');
          return;
        }
        if (!active) {
          await _deny(rawRole == 'dealer'
              ? 'Dealership suspended. Contact AutoServe support.'
              : 'Account deactivated. Contact your admin.');
          return;
        }

        final role = _map(rawRole);
        if (needsPwChange) {
          state = AuthState(
            status: AuthStatus.requiresPasswordChange,
            role: role, userId: u.id,
            dealershipId: dealer, displayName: name,
          );
          return;
        }

        state = AuthState(
          status: AuthStatus.authenticated, role: role,
          userId: u.id, dealershipId: dealer, displayName: name,
        );
        if (kDebugMode) print('✅ users role=$rawRole');
        return;
      }

      // 3. Not found
      if (kDebugMode) {
        print('❌ ${u.id} not in dealer_staff or users');
        print("  INSERT INTO dealer_staff(dealer_id,user_id,full_name,role,status)");
        print("  VALUES('DEALER-UUID','${u.id}','Name','owner','active');");
      }
      await _deny('Access denied. Account not registered. Contact admin.');
    } on PostgrestException catch (e) {
      if (kDebugMode) print('❌ Postgrest: ${e.code} ${e.message}');
      await _deny('Could not verify account: ${e.message}');
    } catch (e) {
      if (kDebugMode) print('❌ Unexpected: $e');
      await _deny('Failed to verify account. Please try again.');
    }
  }

  AppRole _map(String r) {
    switch (r) {
      case 'admin':  return AppRole.admin;
      case 'dealer': return AppRole.dealerOwner;
      default:       return AppRole.staff;
    }
  }

  Future<void> _deny(String msg) async {
    if (kDebugMode) print('🚫 $msg');
    await _c.auth.signOut();
    state = AuthState(status: AuthStatus.error, errorMessage: msg);
  }

  // ── Update password (used by UpdatePasswordScreen) ───────────────────────────

  Future<String?> updatePassword(String newPassword) async {
    try {
      await _c.auth.updateUser(UserAttributes(password: newPassword));

      // Clear the requires_password_change flag in DB
      final uid = state.userId ?? _c.auth.currentUser?.id;
      if (uid != null) {
        // Try dealer_staff first, then users
        try {
          await _c.from('dealer_staff')
              .update({'requires_password_change': false}).eq('user_id', uid);
        } catch (_) {
          try {
            await _c.from('users')
                .update({'requires_password_change': false}).eq('id', uid);
          } catch (_) {}
        }
      }

      // Transition to authenticated
      state = state.copyWith(status: AuthStatus.authenticated);
      return null; // null = success
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // ── Update profile ───────────────────────────────────────────────────────────

  Future<String?> updateProfile({required String displayName}) async {
    try {
      final uid = state.userId ?? _c.auth.currentUser?.id;
      if (uid == null) return 'Not authenticated.';

      // Try dealer_staff first
      try {
        await _c.from('dealer_staff')
            .update({'full_name': displayName}).eq('user_id', uid);
      } catch (_) {
        await _c.from('users')
            .update({'full_name': displayName}).eq('id', uid);
      }

      state = state.copyWith(displayName: displayName);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ── Refresh session ───────────────────────────────────────────────────────────

  Future<void> refreshSession() async {
    if (_kDevMode) return;
    final u = _c.auth.currentUser;
    if (u == null) { state = state.copyWith(status: AuthStatus.unauthenticated); return; }
    state = state.copyWith(status: AuthStatus.loading);
    await _resolveRole(u);
  }

  // ── Sign out — clears ALL Riverpod caches to prevent data leakage ────────────

  Future<void> signOut() async {
    if (_kDevMode) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }

    // Invalidate data caches BEFORE signing out so providers
    // can't fire one last read with the old user's credentials.
    _ref.invalidate(dealerVehiclesStreamProviderFamily);
    _ref.invalidate(dealerLeadsStreamProviderFamily);
    _ref.invalidate(dashboardMetricsProviderFamily);
    _ref.invalidate(currentDealershipProviderFamily);

    await _c.auth.signOut();
    // State reset is handled by the onAuthStateChange.signedOut listener above.
  }

  void clearError() {
    if (state.status == AuthStatus.error) {
      state = state.copyWith(
          status: AuthStatus.unauthenticated, errorMessage: null);
    }
  }

  void clearSessionExpired() => state = state.copyWith(sessionExpired: false);

  String _friendly(String raw) {
    final l = raw.toLowerCase();
    if (l.contains('invalid login') || l.contains('invalid credentials'))
      return 'Incorrect email or password.';
    if (l.contains('email not confirmed'))
      return 'Please verify your email before logging in.';
    if (l.contains('too many requests'))
      return 'Too many attempts. Please wait and try again.';
    return raw;
  }
}

// ── Provider families (used for targeted cache invalidation) ─────────────────
// These are referenced by auth_provider for invalidation on logout.
// Actual implementations live in vehicle_provider / lead_provider / overview_provider.
// We declare empty family providers here as sentinel keys so _ref.invalidate works.

final dealerVehiclesStreamProviderFamily = Provider.family<void, String?>((ref, id) {});
final dealerLeadsStreamProviderFamily    = Provider.family<void, String?>((ref, id) {});
final dashboardMetricsProviderFamily     = Provider.family<void, String?>((ref, id) {});
final currentDealershipProviderFamily    = Provider.family<void, String?>((ref, id) {});

// ── Main providers ────────────────────────────────────────────────────────────

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
    (ref) => AuthNotifier(ref));

final isAuthenticatedProvider =
    Provider<bool>((ref) => ref.watch(authProvider).isAuthenticated);

final currentRoleProvider =
    Provider<AppRole>((ref) => ref.watch(authProvider).role);

final currentDealershipIdProvider =
    Provider<String?>((ref) => ref.watch(authProvider).dealershipId);


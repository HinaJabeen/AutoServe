// apps/dashboard/lib/widgets/role_gate.dart
//
// Usage:
//   RoleGate(
//     allowed: const [AppRole.admin, AppRole.dealerOwner],
//     child: DeleteDealerButton(),
//   )
//
// Rebuild safety: uses select() so the widget ONLY rebuilds when the role
// value itself changes — not on every AuthState mutation (e.g. displayName).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dashboard/features/providers/auth_provider.dart';

class RoleGate extends ConsumerWidget {
  const RoleGate({
    super.key,
    required this.allowed,
    required this.child,
    this.fallback,
  });

  /// Roles that are permitted to see [child].
  final List<AppRole> allowed;

  /// Shown when the user's role is not in [allowed].
  /// Defaults to [SizedBox.shrink()].
  final Widget? fallback;

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // select() means we only re-render when the role enum value changes,
    // not on every other AuthState field update — prevents layout thrash.
    final role = ref.watch(authProvider.select((s) => s.role));
    return allowed.contains(role) ? child : (fallback ?? const SizedBox.shrink());
  }
}

// Convenience: single-role shorthand
class RequireRole extends RoleGate {
  const RequireRole({
    super.key,
    required AppRole role,
    required super.child,
    super.fallback,
  }) : super(allowed: const [], // overridden below
       );

  // Dart doesn't allow non-const expressions in super-initialiser lists,
  // so we wrap with a thin factory instead.
  static Widget of({
    Key? key,
    required AppRole role,
    required Widget child,
    Widget? fallback,
  }) => RoleGate(
    key: key,
    allowed: [role],
    child: child,
    fallback: fallback,
  );
}

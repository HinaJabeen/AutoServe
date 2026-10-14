// lib/features/auth/models/customer_profile.dart

/// Mirrors the `profiles.role` check constraint. `profiles.role` is a
/// read-only mirror of dealer_staff/admin_users maintained by DB triggers —
/// see backend/supabase/supabase/migrations/20261013160000_customer_profiles.sql.
enum ProfileRole {
  customer,
  dealer,
  admin;

  /// Anything unrecognised is treated as non-customer, so an unexpected
  /// value fails closed (blocked at login) rather than being let in.
  static ProfileRole fromDb(String? value) => switch (value) {
        'customer' => ProfileRole.customer,
        'admin' => ProfileRole.admin,
        _ => ProfileRole.dealer,
      };
}

/// A row of `profiles`, plus the email from the Supabase Auth user (email
/// lives on auth.users only — it isn't duplicated into the table).
class CustomerProfile {
  const CustomerProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.phone,
  });

  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final ProfileRole role;

  bool get isCustomer => role == ProfileRole.customer;

  /// Up to two initials for the avatar; falls back to the email's first letter.
  String get initials {
    final parts =
        fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return email.isEmpty ? '?' : email[0].toUpperCase();
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory CustomerProfile.fromJson(
    Map<String, dynamic> json, {
    required String email,
  }) {
    return CustomerProfile(
      id: json['id'] as String,
      email: email,
      fullName: json['full_name'] as String? ?? '',
      phone: json['phone'] as String?,
      role: ProfileRole.fromDb(json['role'] as String?),
    );
  }
}

// lib/features/leads/providers/lead_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../services/lead_service.dart';

final leadServiceProvider =
    Provider<LeadService>((ref) => LeadService(SupabaseService.client));

class LeadSubmissionState {
  const LeadSubmissionState({this.isSubmitting = false, this.errorMessage});
  final bool isSubmitting;
  final String? errorMessage;
}

class LeadSubmissionNotifier extends StateNotifier<LeadSubmissionState> {
  LeadSubmissionNotifier(this._service) : super(const LeadSubmissionState());
  final LeadService _service;

  /// Returns true on success; on failure the message lands in [state].
  Future<bool> submit({
    required LeadType type,
    required CarModel car,
    required String fullName,
    required String phone,
    required String email,
    String? message,
    DateTime? preferredDate,
  }) async {
    if (state.isSubmitting) return false;
    state = const LeadSubmissionState(isSubmitting: true);
    try {
      await _service.submit(
        type: type,
        car: car,
        fullName: fullName,
        phone: phone,
        email: email,
        message: message,
        preferredDate: preferredDate,
      );
      if (mounted) state = const LeadSubmissionState();
      return true;
    } on LeadSubmissionException catch (e) {
      if (mounted) state = LeadSubmissionState(errorMessage: e.message);
      return false;
    }
  }
}

// autoDispose so each opening of the sheet starts clean — a stale error from
// a previous attempt on another car shouldn't greet the next one.
final leadSubmissionProvider = StateNotifierProvider.autoDispose<
    LeadSubmissionNotifier, LeadSubmissionState>(
  (ref) => LeadSubmissionNotifier(ref.read(leadServiceProvider)),
);

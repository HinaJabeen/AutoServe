// lib/features/dealer_application/providers/dealer_application_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../auth/providers/auth_providers.dart';
import '../models/dealer_application.dart';
import '../services/dealer_application_service.dart';

final dealerApplicationServiceProvider = Provider<DealerApplicationService>(
    (ref) => DealerApplicationService(SupabaseService.client));

/// The signed-in user's application (null = never applied). Rebuilt when the
/// user changes, so one account never sees another's application.
final myDealerApplicationProvider = FutureProvider<DealerApplication?>((ref) async {
  final userId = ref.watch(currentProfileProvider.select((p) => p?.id));
  if (userId == null) return null;
  return ref.read(dealerApplicationServiceProvider).fetchMine();
});

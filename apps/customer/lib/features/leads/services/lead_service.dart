// lib/features/leads/services/lead_service.dart
//
// The only place the customer app writes to `leads`. Column names follow the
// live schema (20260630062555_initial_schema.sql), which is also exactly what
// the dashboard's Kanban stream reads (apps/dashboard/.../lead_provider.dart):
// `dealer_id`, `car_id`, `customer_name`, `customer_phone`, `source`,
// `stage`, `notes`. There is no `customer_id`/`email`/`type`/`status`/
// `message` column — the request type goes in `source`, the pipeline column
// is `stage`, and email/date/message are folded into `notes`.

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared/shared.dart';

enum LeadType {
  testDrive('test_drive_request'),
  inquiry('inquiry');

  const LeadType(this.source);

  /// Must stay inside the `leads_source_check` allow-list
  /// (20261014090000_leads_source_check.sql).
  final String source;
}

class LeadSubmissionException implements Exception {
  LeadSubmissionException(this.message);
  final String message;
  @override
  String toString() => message;
}

class LeadService {
  LeadService(this._client);
  final SupabaseClient _client;

  static const _timeout = Duration(seconds: 20);

  Future<void> submit({
    required LeadType type,
    required CarModel car,
    required String fullName,
    required String phone,
    required String email,
    String? message,
    DateTime? preferredDate,
  }) async {
    try {
      await _client.from('leads').insert({
        'dealer_id': car.dealerId,
        'car_id': car.id,
        'customer_name': fullName,
        'customer_phone': phone,
        'source': type.source,
        'stage': 'new',
        'notes': buildNotes(
          type: type,
          email: email,
          message: message,
          preferredDate: preferredDate,
        ),
      }).timeout(_timeout);
    } on PostgrestException catch (e) {
      throw LeadSubmissionException(
          "Couldn't send your request (${e.message}). Please try again.");
    } catch (_) {
      throw LeadSubmissionException(
          "Couldn't reach AutoServe. Check your connection and try again.");
    }
  }

  static String buildNotes({
    required LeadType type,
    required String email,
    String? message,
    DateTime? preferredDate,
  }) {
    final lines = <String>[
      switch (type) {
        LeadType.testDrive => preferredDate == null
            ? 'Test drive requested.'
            : 'Test drive requested for ${formatDate(preferredDate)}.',
        LeadType.inquiry => 'Vehicle inquiry.',
      },
      if (message != null && message.trim().isNotEmpty) 'Message: ${message.trim()}',
      'Contact email: $email',
    ];
    return lines.join('\n');
  }

  static String formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

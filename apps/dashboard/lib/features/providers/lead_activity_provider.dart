// lib/features/providers/lead_activity_provider.dart
//
// Internal dealer notes on a lead, stored in the existing `lead_activity`
// table. The LIVE columns are id, lead_id, actor_id, action, detail,
// created_at (the repo migration's activity_type/note columns don't exist
// in production), so a note is a row with action = 'note' and its text in
// `detail`.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LeadNote {
  const LeadNote({
    required this.id,
    required this.note,
    required this.createdAt,
    this.actorId,
  });

  final String id;
  final String note;
  final DateTime createdAt;
  final String? actorId;

  factory LeadNote.fromJson(Map<String, dynamic> json) => LeadNote(
        id: json['id'].toString(),
        note: _detailText(json['detail']),
        actorId: json['actor_id']?.toString(),
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
            DateTime.now(),
      );
}

/// `detail` may be text or jsonb; a jsonb string comes back as a String,
/// and anything structured is shown as-is rather than dropped.
String _detailText(Object? detail) => switch (detail) {
      null => '',
      String s => s,
      Map m when m['note'] != null => m['note'].toString(),
      _ => detail.toString(),
    };

/// Newest first.
final leadNotesProvider =
    FutureProvider.autoDispose.family<List<LeadNote>, String>((ref, leadId) async {
  final rows = await SupabaseService.client
      .from('lead_activity')
      .select('id, detail, actor_id, created_at')
      .eq('lead_id', leadId)
      .eq('action', 'note')
      .order('created_at', ascending: false);
  return rows.map((r) => LeadNote.fromJson(Map<String, dynamic>.from(r))).toList();
});

/// Returns null on success, or an error message.
Future<String?> addLeadNote(WidgetRef ref, String leadId, String note) async {
  final text = note.trim();
  if (text.isEmpty) return 'Write a note first.';
  try {
    await SupabaseService.client.from('lead_activity').insert({
      'lead_id': leadId,
      'actor_id': SupabaseService.client.auth.currentUser?.id,
      'action': 'note',
      'detail': text,
    });
    ref.invalidate(leadNotesProvider(leadId));
    return null;
  } on PostgrestException catch (e) {
    debugPrint('addLeadNote: ${e.code} ${e.message} details=${e.details}');
    return 'Could not save note: ${e.message}';
  }
}

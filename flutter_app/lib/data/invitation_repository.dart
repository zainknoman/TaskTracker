import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/supabase_config.dart';
import '../models/invitation.dart';
import 'exceptions.dart';

class InvitationRepository {
  final SupabaseClient _client;
  InvitationRepository({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  Future<Invitation> create(String workspaceId, String role) async {
    try {
      final token = const Uuid().v4();
      final row = await _client
          .from('invitations')
          .insert({
            'workspace_id': workspaceId,
            'token': token,
            'role': role,
            'invited_by': _client.auth.currentUser!.id,
            'expires_at': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
          })
          .select()
          .single();
      return Invitation.fromJson(row);
    } on PostgrestException catch (e) {
      throw mapPostgrestError(e);
    }
  }

  /// Calls the `accept_invitation` RPC (SECURITY DEFINER) documented in
  /// migrations/004_accept_invitation_rpc.sql.
  Future<void> accept(String token, String userId) async {
    try {
      await _client.rpc('accept_invitation', params: {'p_token': token, 'p_user_id': userId});
    } on PostgrestException catch (e) {
      throw mapPostgrestError(e);
    }
  }

  Future<void> cancel(String id) async {
    try {
      await _client.from('invitations').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw mapPostgrestError(e);
    }
  }
}

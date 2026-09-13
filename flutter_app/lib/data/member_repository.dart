import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import '../models/workspace_member.dart';
import 'exceptions.dart';

class MemberRepository {
  final SupabaseClient _client;
  MemberRepository({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  Future<List<WorkspaceMember>> listForWorkspace(String workspaceId) async {
    try {
      final rows = await _client.from('workspace_members').select().eq('workspace_id', workspaceId);
      return rows.map((r) => WorkspaceMember.fromJson(r)).toList();
    } on PostgrestException catch (e) {
      throw mapPostgrestError(e);
    }
  }

  Future<WorkspaceMember> updateProfile(WorkspaceMember member) async {
    try {
      final row = await _client
          .from('workspace_members')
          .update(member.toJson())
          .eq('id', member.id)
          .select()
          .single();
      return WorkspaceMember.fromJson(row);
    } on PostgrestException catch (e) {
      throw mapPostgrestError(e);
    }
  }

  Future<void> remove(String memberId) async {
    try {
      await _client.from('workspace_members').delete().eq('id', memberId);
    } on PostgrestException catch (e) {
      throw mapPostgrestError(e);
    }
  }

  Stream<List<WorkspaceMember>> streamForWorkspace(String workspaceId) {
    return _client
        .from('workspace_members')
        .stream(primaryKey: ['id'])
        .eq('workspace_id', workspaceId)
        .map((rows) => rows.map((r) => WorkspaceMember.fromJson(r)).toList());
  }
}

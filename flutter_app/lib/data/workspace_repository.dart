import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import '../models/workspace.dart';
import 'exceptions.dart';

class WorkspaceRepository {
  final SupabaseClient _client;
  WorkspaceRepository({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  /// Lists every workspace the current user belongs to, via the
  /// `workspace_members` join table (mirrors js/workspace.js).
  Future<List<Workspace>> listForUser() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];
      final rows = await _client
          .from('workspace_members')
          .select('workspaces(*)')
          .eq('user_id', userId);
      return rows
          .where((r) => r['workspaces'] != null)
          .map((r) => Workspace.fromJson(r['workspaces'] as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw mapPostgrestError(e);
    }
  }

  /// Creates a workspace; the DB's owner-auto-join trigger adds the
  /// current user as `owner` in `workspace_members`.
  Future<Workspace> create(String name) async {
    try {
      final slug = name.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
      final row = await _client
          .from('workspaces')
          .insert({
            'name': name,
            'slug': slug,
            'owner_id': _client.auth.currentUser!.id,
          })
          .select()
          .single();
      return Workspace.fromJson(row);
    } on PostgrestException catch (e) {
      throw mapPostgrestError(e);
    }
  }
}

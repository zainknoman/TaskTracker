import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import '../models/project.dart';
import 'exceptions.dart';

/// Reads/writes the `tt_projects` table (not `projects` - see readme.md
/// "Known issue: shared Supabase project table collision").
class ProjectRepository {
  final SupabaseClient _client;
  ProjectRepository({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  Future<List<Project>> listForWorkspace(String workspaceId) async {
    try {
      final rows = await _client.from('tt_projects').select().eq('workspace_id', workspaceId);
      return rows.map((r) => Project.fromJson(r)).toList();
    } on PostgrestException catch (e) {
      throw mapPostgrestError(e);
    }
  }

  Future<Project> create(Project project) async {
    try {
      final payload = project.toJson()..remove('id');
      final row = await _client.from('tt_projects').insert(payload).select().single();
      return Project.fromJson(row);
    } on PostgrestException catch (e) {
      throw mapPostgrestError(e);
    }
  }

  Future<Project> update(Project project) async {
    try {
      final row =
          await _client.from('tt_projects').update(project.toJson()).eq('id', project.id).select().single();
      return Project.fromJson(row);
    } on PostgrestException catch (e) {
      throw mapPostgrestError(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _client.from('tt_projects').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw mapPostgrestError(e);
    }
  }

  Stream<List<Project>> streamForWorkspace(String workspaceId) {
    return _client
        .from('tt_projects')
        .stream(primaryKey: ['id'])
        .eq('workspace_id', workspaceId)
        .map((rows) => rows.map((r) => Project.fromJson(r)).toList());
  }
}
